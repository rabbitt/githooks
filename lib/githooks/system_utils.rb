# sublime: x_syntax Packages/Ruby/Ruby.tmLanguage
# sublime: translate_tabs_to_spaces true; tab_size 2

require 'pathname'
require 'tempfile'
require 'shellwords'

module GitHooks
  module SystemUtils
    def which(name)
      find_bin(name).first
    end
    module_function :which

    def find_bin(name)
      ENV['PATH'].split(/:/).collect { |path|
        Pathname.new(path) + name.to_s
      }.select { |path|
        path.exist? && path.executable?
      }.collect(&:to_s)
    end
    module_function :find_bin

    def with_path(path, &_block)
      fail ArgumentError, 'Missing required block' unless block_given?
      begin
        cwd = Dir.getwd
        Dir.chdir path
        yield path
      ensure
        Dir.chdir cwd
      end
    end
    module_function :with_path

    def command(name)
      (@commands ||= {})[name] ||= begin
        Command.new(name).tap { |cmd|
          define_method("command_#{cmd.name}") { |*args| cmd.execute(*args) }
          alias_method cmd.method, "command_#{cmd.name}"
        }
      end
    end
    module_function :command

    def commands(*names)
      names.each { |name| command(name) }
    end
    module_function :commands

    class Command
      include Shellwords

      ENV_WHITELIST = %w(
        PATH HOME LDFLAGS CPPFLAGS DISPLAY EDITOR
        LANG LC_ALL SHELL SHLVL TERM TMPDIR USER HOME
        SSH_USER SSH_AUTH_SOCK
        GEM_HOME GEM_PATH MY_RUBY_HOME
        GIT_DIR GIT_AUTHOR_DATE GIT_INDEX_FILE GIT_AUTHOR_NAME GIT_PREFIX GIT_AUTHOR_EMAIL
      ) unless defined? ENV_WHITELIST

      class Result
        attr_accessor :output, :error
        attr_reader :status
        def initialize(output, error, status)
          @output = output.strip
          @error  = error.strip
          @status = status
        end

        def output_lines(prefix = nil)
          @output.split(/\n/).collect { |line|
            prefix ? "#{prefix}: #{line}" : line
          }
        end

        def error_lines(prefix = nil)
          @error.split(/\n/).collect { |line|
            prefix ? "#{prefix}: #{line}" : line
          }
        end

        def sanitize!(*args)
          @output.sanitize!(*args)
          @error.sanitize!(*args)
        end

        def success?
          status? ? @status.success? : false
        end

        def failure?
          !success?
        end

        def status?
          !!@status
        end

        def exitstatus
          status? ? @status.exitstatus : -1
        end
        alias_method :code, :exitstatus
      end

      attr_reader :run_path, :bin_path, :name

      def initialize(name, options = {})
        @bin_path = options.delete(:bin_path) || SystemUtils.which(name) || name
        @run_path = options.delete(:chdir)
        @name     = name.to_s.gsub(/([\W-]+)/, '_')
      end

      def method
        @name.to_sym
      end

      def build_command(args, options)
        Array(args).unshift(command_path(options))
      end

      def command_path(options = {})
        options.delete(:use_name) ? name : bin_path.to_s
      end

      def sanitize_env(env = ENV.to_h, options = {})
        include_keys = options.delete(:include) || ENV_WHITELIST
        exclude_keys = options.delete(:exclude) || []

        unless exclude_keys.empty? ^ include_keys.empty?
          fail ArgumentError, 'include and exclude are mutually exclusive'
        end

        env.to_h.reject do |key, _|
          exclude_keys.include?(key) || !include_keys.include?(key)
        end
      end

      def with_sanitized_env(env = {})
        env ||= {}
        old_env = ENV.to_h
        new_env = sanitize_env(
          ENV.to_h.merge(env),
          include: ENV_WHITELIST | env.keys
        )

        begin
          ENV.replace(new_env)
          yield
        ensure
          ENV.replace(old_env)
        end
      end

      def execute(*args, &_block) # rubocop:disable MethodLength, CyclomaticComplexity, AbcSize, PerceivedComplexity
        options = args.extract_options!

        command = build_command(args, options)
        command.unshift("cd #{run_path} ;") if run_path
        command.unshift('sudo') if options.delete(:use_sudo)
        command = Array(command.flatten.join(' '))

        command.unshift options.delete(:pre_pipe)  if options[:pre_pipe]
        command.push options.delete(:post_pipe) if options[:post_pipe]
        command = Array(command.flatten.join('|'))

        command.unshift options.delete(:pre_run)  if options[:pre_run]
        command.push options.delete(:post_run) if options[:post_run]
        command = shellwords(command.flatten.join(';'))

        error_file = Tempfile.new('ghstderr')

        script_file = Tempfile.new('ghscript')
        script_file.puts "exec 2>#{error_file.path}"
        script_file.puts command.join(' ')

        script_file.rewind

        begin
          real_command = "/usr/bin/env bash #{script_file.path}"

          output = with_sanitized_env(options.delete(:env)) do
            %x{ #{real_command} }
          end

          result = Result.new(output, error_file.read, $?)

          if GitHooks.verbose?
            if result.failure?
              STDERR.puts "---\nCommand failed with exit code [#{result.status.exitstatus}]",
                          "COMMAND: #{command.join(' ')}\n",
                          result.output.strip.empty? ? '' : "OUTPUT:\n#{result.output}\n---\n",
                          result.error.strip.empty? ? '' : "ERROR:\n#{result.error}\n---\n"
            else
              STDERR.puts "---\nCommand succeeded with exit code [#{result.status.exitstatus}]",
                          "COMMAND: #{command.join(' ')}\n",
                          result.output.strip.empty? ? '' : "OUTPUT:\n#{result.output}\n---\n",
                          result.error.strip.empty? ? '' : "ERROR:\n#{result.error}\n---\n"
            end
          end

          sanitize = [ :strip, :non_printable ]
          sanitize << :colors unless options.delete(:color)
          sanitize << :empty_lines if options.delete(:strip_empty_lines)
          result.sanitize!(*sanitize)

          result.tap { yield(result) if block_given? }
        ensure
          script_file.close
          script_file.unlink

          error_file.close
          error_file.unlink
        end
      end
      alias_method :call, :execute
    end
  end
end
