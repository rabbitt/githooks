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
    VALID_PHASES = %w{ pre-commit commit-msg pre-push }.freeze unless defined? VALID_PHASES

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

    attr_reader :sections, :phase, :repository, :repository_path, :limiters
    attr_accessor :args, :staged, :untracked, :tracked

    def initialize(phase)
      @phase      = phase.to_s
      @sections   = {}
      @limiters   = {}
      @commands   = []
      @args       = []
      @staged     = true
      @tracked    = false
      @untracked  = false
      @repository = Repository.new(Dir.getwd)
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
      @commands.find { |command| command.name == name.to_s }
    end

    def sections
      @sections.values
    end

    # DSL methods

    # FIXME: these should be switched to behaviors that are included
    # into this classs

    def config_path
      GitHooks.hooks_root.join('configs')
    end

    def config_file(*path_components)
      config_path.join(*path_components)
    end

    def lib_path
      GitHooks.hooks_root.join('lib')
    end

    def lib_file(*path_components)
      lib_path.join(*path_components)
    end

    def limit(type)
      unless @limiters.include? type
        @limiters[type] ||= Repository::Limiter.new(type)
      end
      @limiters[type]
    end

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

      def repository
        @hook.repository
      end

      def files # rubocop:disable AbcSize,MethodLength
        @files ||= begin
          options = {
            staged:    hook.staged,
            tracked:   hook.tracked,
            untracked: hook.untracked
          }

          if %w[ commit-msg pre-push ].include? hook.phase
            begin
              parent_sha = repository.last_unpushed_commit_parent_sha || \
                           repository.branch_point_sha
              options.merge!(ref: parent_sha) if parent_sha
            rescue Error::RemoteNotSet
              STDERR.puts 'Couldn\'t find starting reference point for push ' \
                          'manifest generation. Falling back to all tracked files.'
              # remote not set yet, so let's only focus on what's tracked for now
              options[:tracked]   = true
              options[:untracked] = false
              options[:staged]    = false
            end
          end

          repository.manifest(options)
        end
      end

      def filter(limiters)
        files.dup.tap do |files|
          limiters.each do |type, limiter|
            STDERR.puts "Limiter [#{type}] -> (#{limiter.only.inspect}) match against: " if GitHooks.debug?
            limiter.limit(files)
          end
        end
      end
    end
  end
end
