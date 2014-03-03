# encoding: utf-8
require 'pathname'
require 'open3'
require 'ostruct'

module GitHooks
  module SystemUtils
    def which(name)
      find_bin(name).first
    end
    module_function :which

    def find_bin(name)
      # rubocop:disable MultilineBlockChain, Blocks
      ENV['PATH'].split(/:/).collect {
        |path| Pathname.new(path) + name.to_s
      }.select { |path|
        path.exist? && path.executable?
      }.collect(&:to_s)
      # rubocop:enable MultilineBlockChain, Blocks
    end
    module_function :find_bin

    def with_path(path, &block)
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

    class Command
      include Shellwords

      attr_reader :aliases, :path, :name
      def initialize(name, options = {})
        @name = name
        @path = options.delete(:path) || SystemUtils.which(name)

        @aliases = options.delete(:aliases) || []
        @aliases << name
        @aliases.collect! { |_alias| normalize(_alias) }
        @aliases.uniq!
      end

      def command_path
        path || name.to_s
      end

      def execute(*args, &block) # rubocop:disable MethodLength, CyclomaticComplexity
        options = args.extract_options
        change_to_path    = options.delete(:path)
        strip_empty_lines = !!options.delete(:strip_empty_lines)

        args = [args].flatten
        args.collect! { |arg| arg.is_a?(Repository::File) ? arg.path.to_s : arg }
        args.collect!(&:to_s)

        command = shelljoin([command_path] | args)
        command = ("cd #{shellescape(change_to_path.to_s)} ; " + command) unless path.nil?

        result = OpenStruct.new(output: nil, error: nil, status: nil).tap do |r|
          # puts "#{Dir.getwd} $ #{command}"
          r.output, r.error, r.status = Open3.capture3(command)
          if strip_empty_lines
            r.output = r.output.strip_empty_lines!
            r.error  = r.error.strip_empty_lines!
          end
        end

        block_given? ? yield(result) : result
      end
      alias_method :call, :execute

      def normalize(name)
        name.to_s.gsub(/[^a-z_]+/, '_')
      end
      private :normalize
    end
  end
end
