# encoding: utf-8
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
    @__phases__ = {}
    @__mutex__  = Mutex.new

    class << self
      # rubocop:disable TrivialAccessors
      def instances
        @__phases__
      end
      alias_method :phases, :instances
      # rubocop:enable TrivialAccessors

      def instance(phase = 'pre-commit')
        phase = phase.to_s.gsub('_', '-').to_sym
        unless GitHooks::VALID_PHASES.include? phase
          valid_phases = GitHooks::VALID_PHASES.collect(&:inspect).join(', ')
          fail ArgumentError, "Hook phase (#{phase.inspect}) must be one of #{valid_phases}"
        end

        return phases[phase] if phases[phase]

        @__mutex__.synchronize do
          return phases[phase] if phases[phase]
          phases[phase] = new(phase)
        end
      end
      private :instance

      alias_method :[], :instance
      private :[]

      def method_missing(method, *args, &block)
        return super unless instance.public_methods.include? method
        instance.public_send(method, *args, &block)
      end

      def register(phase, &block)
        fail ArgumentError, 'Missing required block to #register' unless block_given?
        self[phase].instance_eval(&block)
      end
    end

    attr_reader :sections, :phase, :repository

    def initialize(phase)
      @phase      = phase
      @sections   = []
      @commands   = []
      @repository = Repository.new(GitHooks::SCRIPT_PATH)
    end

    def manifest
      @manifest ||= Manifest.new(@repository.manifest)
    end

    def run
      # only run sections that have actions matching files in the manifest
      runable_sections = @sections.select { |section| !section.actions.empty? }
      runable_sections.collect { |section| section.run }.all?
    end

    def method_missing(method, *args, &block)
      command = find_command(method)
      return super unless command
      command.call(*args, &block)
    end

    def setup_command(name, options = {})
      name    = name.to_s.to_sym

      @commands << Command.new(
        name,
        path: options.delete(:path),
        aliases: options.delete(:aliases) || options.delete(:alias)
      )
    end
    private :setup_command

    def find_command(name)
      @commands.select { |command| command.aliases.include? name.to_s }.first
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
      self
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
      include Shellwords

      attr_reader :aliases, :path, :name
      def initialize(name, options = {})
        @name = name
        @path = options.delete(:path) || Utils.which(name)

        @aliases = options.delete(:aliases) || []
        @aliases << name
        @aliases.collect! { |_alias| normalize(_alias) }
        @aliases.uniq!
      end

      def command_path
        path || name.to_s
      end

      def call(*args, &block)
        args = [args].flatten
        args.collect! { |arg| arg.is_a?(Repository::File) ? arg.path.to_s : arg }
        args.collect!(&:to_s)

        command = shelljoin([command_path] | args)

        result = OpenStruct.new(output: nil, error: nil, status: nil).tap do |r|
          r.output, r.error, r.status = Open3.capture3(command)
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
