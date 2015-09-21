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
      # rubocop:disable MultilineBlockChain, Blocks
      ENV['PATH'].split(/:/).collect { |path|
        Pathname.new(path) + name.to_s
      }.select { |path|
        path.exist? && path.executable?
      }.collect(&:to_s)
      # rubocop:enable MultilineBlockChain, Blocks
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

    def quiet(&_block)
      od, ov = GitHooks.debug, GitHooks.verbose
      GitHooks.debug, GitHooks.verbose = false, false
      yield
    ensure
      GitHooks.debug, GitHooks.verbose = od, ov
    end
    module_function :quiet

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

      def prep_env(env = ENV, options = {})
        include_keys = options.delete(:include) || ENV_WHITELIST
        exclude_keys = options.delete(:exclude) || []

        if exclude_keys.size > 0 && include_keys.size > 0
          raise ArgumentError, "include and exclude are mutually exclusive"
        end

        Hash[env].each_with_object([]) do |(key, value), array|
          if exclude_keys.size > 0
            next if exclude_keys.include?(key)
          elsif include_keys.size > 0
            next unless include_keys.include?(key)
          end

          array << %Q'#{key}=#{value.inspect}'
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

        command_env    = options.delete(:env) || {}
        whitelist_keys = ENV_WHITELIST | command_env.keys
        environment    = prep_env(ENV.to_h.merge(command_env), include: whitelist_keys).join(' ')

        error_file = Tempfile.new('ghstderr')

        script_file = Tempfile.new('ghscript')
        script_file.puts "exec 2>#{error_file.path}"
        script_file.puts command.join(' ')

        script_file.rewind

        begin
          real_command = "/usr/bin/env -i #{environment} bash #{script_file.path}"

          if GitHooks.verbose?
            $stderr.puts "Command Line  :\n----\n#{real_command}\n----\n"
            $stderr.puts "Command Script:\n----\n#{script_file.read}\n----\n"
          end

          output = %x{ #{real_command} }
          result = Result.new(output, error_file.read, $?)

          if GitHooks.verbose?
            if result.failure?
              STDERR.puts "Command failed with exit code [#{result.status.exitstatus}]",
                          "ENVIRONMENT:\n\t#{environment}\n\n",
                          "COMMAND:\n\t#{command.join(' ')}\n\n",
                          "OUTPUT:\n-----\n#{result.output}\n-----\n\n",
                          "ERROR:\n-----\n#{result.error}\n-----\n\n"
            else
              STDERR.puts "Command succeeded with exit code [#{result.status.exitstatus}]",
                          "OUTPUT:\n-----\n#{result.output}\n-----\n\n",
                          "ERROR:\n-----\n#{result.error}\n-----\n\n"
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
