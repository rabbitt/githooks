=begin
Copyright (C) 2013 Carl P. Corliss

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
=end

require 'open3'

module GitHooks
  class RegistrationError < StandardError; end

  class Hook

    @__instance__ = {}
    @__mutex__    = Mutex.new

    class << self
      def instances
        @__instances__
      end

      def instance(type = :'pre-commit')
        unless GitHooks::VALID_PHASES.include? type
          raise ArgumentError, "Hook phase must be one of #{GitHooks::VALID_PHASES.join(', ')}"
        end

        type = type.to_s.gsub('_', '-').to_sym
        return instances[type] if instances[type]

        @__mutex__.synchronize {
          return instances[type] if instances[type]
          instances[type] = new(type)
        }
      end
      private :instance

      alias :[] :instance
      private :[]

      def method_missing(method, *args, &block)
        return super unless instance.public_methods.include? method
        instance.public_send(method, *args, &block)
      end

      def register(phase, &block)
        raise ArgumentError, "Missing required block to #register" unless block_given?
        self[phase].instance_eval(&block)
      end
    end

    attr_reader :sections, :type, :repository

    def initialize(hook_type)
      @type       = hook_type
      @sections   = []
      @commands   = {}
      @repository = Repository.new(GitHooks::SCRIPT_PATH)
    end

    def manifest
      @manifest ||= Manifest.new(@repository.manifest)
    end

    def run
      # only run sections that tests matching files in the manifest
      @sections.select { |section| section.tests.any? { |test| test.match(manifest) }}
      @sections.collect { |section| section.run }.all?
    end

    def method_missing(method, *args, &block)
      return super unless command = find_command(method)
      command.call(*args, &block)
    end

    def setup_command(name, options = {})
      name    = name.to_s.to_sym

      @commands[name.to_sym] = Command.new(
        name,
        path: options.delete(:path),
        aliases: options.delete(:aliases) || options.delete(:alias)
      )
    end
    private :setup_command

    def find_command(name)
      @commands.select { |command| command.aliases.include? method }.first
    end

    # DSL methods

    def command(name, options = {})
      setup_command name, options
    end

    def commands(*names)
      return @commands if names.empty?
      names.each { |name| command name }
    end

    def section(name, &block)
      @sections << Section.new(name, self, &block)
    end

    class Manifest
      def initialize(files)
        @files = files
      end

      def filter(limiters)
        @files.dup.tap do |files|
          limiters.each { |limiter| limiter.limit(files) }
        end
      end
    end

    class Command
      attr_reader :aliases, :path,
      def initialize(name, options = {})
        @name = name
        @path = options.delete(:path) || Utils.which(name)

        @aliases = options.delete(:aliases) || []
        @aliases << name
        @aliases.collect!{ |name| normalize(name) }
        @aliases.uniq!
      end

      def command
        name.to_s || path
      end

      def call(*args, &block)
        args = [args].flatten
        args.collect!{ |arg| arg.is_a?(Repository::File) ? arg.path.to_s : arg }
        args.collect!(&:to_s)

        command = shelljoin([command] | args)

        result = OpenStruct.new(output: nil, error: nil, status: nil).tap { |result|
          result.output, result.error, result.status = Open3.capture3(command)
          class << result.status
            def failed?() !success?; end
          end
        end

        block_given? ? yield(result) : result
      end

      def normalize(name)
        name.to_s.gsub(/[^a-z_]+/, '_')
      end
      private :normalize
    end
  end
end