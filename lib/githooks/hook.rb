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

require_relative 'repository'
require_relative 'system_utils'

module GitHooks
  class Hook
    VALID_PHASES = %w{ pre-commit commit-msg }.freeze

    @__phases__ = {}
    @__mutex__  = Mutex.new

    class << self
      attr_reader :__phases__
      alias_method :phases, :__phases__

      def instance(phase = 'pre-commit') # rubocop:disable AbcSize
        phase = phase.to_s
        unless VALID_PHASES.include? phase
          fail ArgumentError, "Hook phase (#{phase}) must be one of #{VALID_PHASES.join(', ')}"
        end

        unless phases[phase]
          @__mutex__.synchronize {
            return phases[phase] if phases[phase]
            phases[phase] = new(phase)
          }
        end
        phases[phase]
      end
      private :instance

      alias_method :[], :instance
      private :[]

      def method_missing(method, *args, &block)
        return super unless instance.public_methods.include? method
        instance.public_send(method, *args, &block)
      end

      def register(phase, &block)
        fail ArgumentError, 'expected block, received none' unless block_given?
        instance(phase).instance_eval(&block)
      end
    end

    attr_reader :sections, :phase, :repository, :repository_path
    attr_accessor :args, :staged, :untracked, :tracked

    def initialize(phase)
      @phase     = phase.to_s
      @sections  = {}
      @commands  = []
      @args      = []
      @staged    = true
      @tracked   = false
      @untracked = false

      repository_path = Dir.getwd # rubocop:disable UselessAssignment
    end

    def [](name)
      @sections[name]
    end

    def repository_path=(path)
      @repository = Repository.new(path)
    end

    def manifest
      @manifest ||= Manifest.new(self)
    end

    def run
      # only run sections that have actions matching files in the manifest
      sections.reject { |s| s.actions.empty? }.collect(&:run).all?
    end

    def method_missing(method, *args, &block)
      return super unless command = find_command(method) # rubocop:disable AssignmentInCondition
      command.execute(*args, &block)
    end

    def setup_command(name, options = {})
      @commands << SystemUtils::Command.new(
        name.to_sym,
        chdir: options.delete(:chdir),
        bin_path: options.delete(:bin_path)
      )
    end
    private :setup_command

    def find_command(name)
      @commands.select { |command| command.name == name.to_s }.first
    end

    def sections
      @sections.values
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
      key_name = Section.key_from_name(name)
      return @sections[key_name] unless block_given?

      if @sections.include? key_name
        @sections[key_name].instance_eval(&block)
      else
        @sections[key_name] ||= Section.new(name, self, &block)
      end
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
          staged:    hook.staged,
          tracked:   hook.tracked,
          untracked: hook.untracked
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
