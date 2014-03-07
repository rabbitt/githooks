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

require_relative 'system_utils'

module GitHooks
  class Hook
    VALID_PHASES = %w{ pre-commit commit-msg }.freeze

    @__phases__ = {}
    @__mutex__  = Mutex.new

    class << self
      def instances # rubocop:disable TrivialAccessors
        @__phases__
      end
      alias_method :phases, :instances

      def instance(phase = 'pre-commit')
        phase = phase.to_s
        unless VALID_PHASES.include? phase
          valid_phases = VALID_PHASES.collect(&:inspect).join(', ')
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

    attr_reader :sections, :phase, :repository, :repository_path
    attr_accessor :args, :unstaged, :untracked

    def initialize(phase)
      @phase     = phase
      @sections  = []
      @commands  = []
      @args      = []
      @unstaged  = false
      @untracked = false

      repository_path = Dir.getwd # rubocop:disable UselessAssignment
    end

    def repository_path=(path)
      @repository = Repository.new(path)
    end

    def manifest(options = {})
      @manifest ||= Manifest.new(self)
    end

    def run
      # only run sections that have actions matching files in the manifest
      runable_sections = @sections.select { |section| !section.actions.empty? }
      runable_sections.collect { |section| section.run }.all?
    end

    def method_missing(method, *args, &block)
      command = find_command(method)
      return super unless command
      command.execute(*args, &block)
    end

    def setup_command(name, options = {})
      name    = name.to_s.to_sym

      @commands << SystemUtils::Command.new(
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
      attr_reader :hook
      private :hook

      def initialize(hook)
        @hook = hook
      end

      def repo
        @hook.repository
      end

      def manifest
        @files ||= repo.manifest(
          untracked: hook.untracked,
          unstaged:  hook.unstaged
        )
      end

      def filter(limiters)
        manifest.dup.tap do |files|
          limiters.each do |limiter|
            puts "Limiter [#{limiter.type}] -> (#{limiter.only.inspect}) match against: " if GitHooks.debug?
            limiter.limit(files)
          end
        end
      end
    end
  end
end
