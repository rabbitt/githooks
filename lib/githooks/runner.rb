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

require 'thor'
require 'fileutils'
require 'shellwords'

require_relative 'error'
require_relative 'hook'
require_relative 'repository'
require_relative 'system_utils'

module GitHooks
  class Runner # rubocop:disable Metrics/ClassLength
    attr_reader :repository, :script, :hook_path, :repo_path, :options
    private :repository, :script, :hook_path, :repo_path, :options

    def initialize(options = {}) # rubocop:disable Metrics/AbcSize
      @repo_path  = Pathname.new(options.delete('repo') || Repository.path)
      @repository = Repository.instance(@repo_path)
      @hook_path  = acquire_hooks_path(options.delete('path') || @repository.config.path || @repository.path)
      @script     = options.delete('script') || @repository.config.script
      @options    = IndifferentAccessOpenStruct.new(options)

      GitHooks.verbose = !!ENV['GITHOOKS_VERBOSE']
      GitHooks.debug   = !!ENV['GITHOOKS_DEBUG']
    end

    # rubocop:disable CyclomaticComplexity, MethodLength, AbcSize, PerceivedComplexity
    def run
      options.staged = options.staged.nil? ? true : options.staged

      if options.skip_pre
        puts 'Skipping PreRun Executables'
      else
        run_externals('pre-run-execute')
      end

      if script && !(options.ignore_script || GitHooks.ignore_script)
        command = "#{script} #{Pathname.new($0)} #{Shellwords.join(ARGV)};"
        puts "Kernel#exec(#{command.inspect})" if GitHooks.verbose
        exec(command)
      elsif hook_path
        load_tests(hook_path, options.skip_bundler)
        start
      else
        puts %q"I can't figure out what to run! Specify either path or script to give me a hint..."
      end

      if options.skip_post
        puts 'Skipping PostRun Executables'
      else
        run_externals('post-run-execute')
      end
    rescue GitHooks::Error::NotAGitRepo => e
      puts "Unable to find a valid git repo in #{repo}."
      puts 'Please specify path to repo via --repo <path>' if GitHooks::SCRIPT_NAME == 'githooks'
      raise e
    end

    def attach
      entry_path   = Pathname.new(options.script || options.path).realdirpath
      hook_phases  = options.hooks || Hook::VALID_PHASES
      bootstrapper = Pathname.new(options.bootstrap).realpath if options.bootstrap

      if entry_path.directory?
        if path = repository.config['path'] # rubocop:disable AssignmentInCondition
          fail Error::AlreadyAttached, "Repository [#{repo_path}] already attached to path #{path} - Detach to continue."
        end
        repository.config.set('path', entry_path)
      elsif entry_path.executable?
        if path = repository.config['script'] # rubocop:disable AssignmentInCondition
          fail Error::AlreadyAttached, "Repository [#{repo_path}] already attached to script #{path}. Detach to continue."
        end
        repository.config.set('script', entry_path)
      else
        fail ArgumentError, "Provided path '#{entry_path}' is neither a directory nor an executable file."
      end

      gitrunner = bootstrapper
      gitrunner ||= SystemUtils.which('githooks-runner')
      gitrunner ||= (GitHooks::BIN_PATH + 'githooks-runner').realpath

      hook_phases.each do |hook|
        hook = (@repository.hooks + hook).to_s
        puts "Linking #{gitrunner} -> #{hook}" if GitHooks.verbose
        FileUtils.ln_sf gitrunner.to_s, hook
      end
    end

    def detach(hook_phases = nil)
      (hook_phases || Hook::VALID_PHASES).each do |hook|
        next unless (repo_hook = (@repository.hooks + hook)).symlink?
        puts "Removing hook '#{hook}' from repository at: #{repository.path}" if GitHooks.verbose
        FileUtils.rm_f repo_hook
      end

      active_hooks = Hook::VALID_PHASES.select { |hook| (@repository.hooks + hook).exist? }

      if active_hooks.empty?
        puts 'All hooks detached. Removing configuration section.'
        repo.config.remove_section(repo_path: repository.path)
      else
        puts "Keeping configuration for active hooks: #{active_hooks.join(', ')}"
      end
    end

    def list
      unless script || hook_path
        fail Error::NotAttached, 'Repository currently not configured. Usage attach to setup for use with githooks.'
      end

      if (executables = repository.config.pre_run_execute).size > 0
        puts 'PreRun Executables (in execution order):'
        puts executables.collect { |exe| "  #{exe}" }.join("\n")
        puts
      end

      if script
        puts 'Main Test Script:'
        puts "  #{script}"
        puts
      end

      if hook_path
        puts 'Main Testing Library with Tests (in execution order):'
        puts '  Tests loaded from:'
        puts "    #{hook_path}"
        puts

        SystemUtils.quiet { load_tests(hook_path, true) }

        %w{ pre-commit commit-msg }.each do |phase|
          next unless Hook.phases[phase]

          puts "  Phase #{phase.camelize}:"
          Hook.phases[phase].sections.each_with_index do |section, section_index|
            printf "    %3d: %s\n", section_index + 1, section.title
            section.actions.each_with_index do |action, action_index|
              printf "      %3d: %s\n", action_index + 1, action.title
              action.limiters.each_with_index do |limiter, limiter_index|
                type, value = limiter.type.inspect, limiter.only
                value = value.first if value.size == 1
                printf "          Limiter %d: %s -> %s\n", limiter_index + 1, type, value.inspect
              end
            end
          end
        end

        puts
      end

      if (executables = repository.config.post_run_execute).size > 0
        puts 'PostRun Executables (in execution order):'
        executables.each do |exe|
          puts "  #{exe}"
        end
        puts
      end
    rescue Error::NotAGitRepo
      puts "Unable to find a valid git repo in #{repository}."
      puts 'Please specify path to repo via --repo <path>' if GitHooks::SCRIPT_NAME == 'githooks'
      raise
    end

  private

    def acquire_hooks_path(path)
      path = Pathname.new(path) unless path.is_a? Pathname
      path.tap do # return input path by default
        return path if path.include? 'hooks'
        return path if path.include? '.hooks'
        return p if (p = path.join('hooks')).exist? # rubocop:disable Lint/UselessAssignment
        return p if (p = path.join('.hooks')).exist? # rubocop:disable Lint/UselessAssignment
      end
    end

    def run_externals(which)
      args = options.args || []
      repository.config[which].all? { |executable|
        command = SystemUtils::Command.new(File.basename(executable), bin_path: executable)

        puts "#{which.camelize}: #{command.build_command(args)}" if GitHooks.verbose
        unless (r = command.execute(*args)).status.success?
          print "#{which.camelize} Executable [#{executable}] failed with error code #{r.status.exitstatus} and "
          if r.error.empty?
            puts 'no output'
          else
            puts "error message:\n\t#{r.error}"
          end
        end
        r.status.success?
      } || fail(TestsFailed, "Failed #{which.camelize} executables - giving up")
    end

    def start # rubocop:disable  CyclomaticComplexity,  MethodLength
      phase = options.hook || GitHooks.hook_name || 'pre-commit'
      puts "PHASE: #{phase}" if GitHooks.debug

      if (active_hook = Hook.phases[phase])
        active_hook.args            = options.args
        active_hook.staged          = options.staged
        active_hook.untracked       = options.untracked
        active_hook.tracked         = options.tracked
        active_hook.repository_path = repository.path
      else
        fail Error::InvalidPhase, "Hook '#{phase}' is not defined - have you registered any tests for this hook yet?"
      end

      success        = active_hook.run
      section_length = active_hook.sections.maximum { |s| s.title.length }
      sections       = active_hook.sections.select { |section| !section.actions.empty? }

      # TODO: refactor to show this in realtime instead of after the hooks have run
      sections.each do |section|
        hash_tail_length = (section_length - section.title.length)
        printf "===== %s %s===== (%ds)\n", section.colored_name(phase), ('=' * hash_tail_length), section.benchmark
        section.actions.each_with_index do |action, index|
          printf "  %d. [ %s ] %s (%ds)\n", (index + 1), action.status_symbol, action.colored_title, action.benchmark

          action.errors.each do |error|
            printf "    %s %s\n", GitHooks::FAILURE_SYMBOL, error
          end

          state_string = action.success? ? GitHooks::SUCCESS_SYMBOL : GitHooks::UNKNOWN_SYMBOL

          action.warnings.each do |warning|
            printf "    %s %s\n", state_string, warning
          end
        end
        puts
      end

      success = false if ENV['GITHOOKS_FORCE_FAIL']

      unless success
        $stderr.puts 'Commit failed due to errors listed above.'
        $stderr.puts 'Please fix and attempt your commit again.'
      end

      exit(success ? 0 : 1)
    end

    def load_tests(hooks_path, skip_bundler = false)
      # hooks stored locally in the repo_root should have their libs, init and
      # gemfile stored in the hooks directory itself, whereas hooks stored
      # in a separate repository should have have them all stored relative
      # to the separate hooks directory.
      if hook_path.to_s.start_with? repository.path
        hook_data_path = acquire_hooks_path(repository.path)
      else
        hook_data_path = acquire_hooks_path(hook_path)
      end

      hooks_libs = hook_data_path.join('lib')
      hooks_init = hook_data_path.join('hooks_init.rb')
      gemfile    = hook_data_path.join('Gemfile')

      GitHooks.hooks_root = hook_data_path

      if gemfile.exist? && !(skip_bundler.nil? ? ENV.include?('GITHOOKS_SKIP_BUNDLER') : skip_bundler)
        puts "loading Gemfile from: #{gemfile}" if GitHooks.verbose

        begin
          ENV['BUNDLE_GEMFILE'] = gemfile.to_s

          # stupid RVM polluting my environment without asking via it's
          # executable-hooks gem preloading bundler. hence the following ...
          if defined? Bundler
            [:@bundle_path, :@configured, :@definition, :@load].each do |var|
              ::Bundler.instance_variable_set(var, nil)
            end
            # bundler tests for @settings using defined? - which means we need
            # to forcibly remove it.
            Bundler.send(:remove_instance_variable, :@settings)
          else
            require 'bundler'
          end
          ::Bundler.require(:default)
        rescue LoadError
          puts %q"Unable to load bundler - please make sure it's installed."
          raise # rubocop:disable SignalException
        rescue ::Bundler::GemNotFound => e
          puts "Error: #{e.message}"
          puts 'Did you bundle install your Gemfile?'
          raise # rubocop:disable SignalException
        end
      end

      $LOAD_PATH.unshift hooks_libs.to_s

      if hooks_init.exist?
        puts "Loading hooks from #{hooks_init} ..." if GitHooks.verbose?
        require hooks_init.sub_ext('').to_s
      else
        puts 'Loading hooks brute-force style ...' if GitHooks.verbose?
        Dir["#{hooks_path}/**/*.rb"].each do |lib|
          lib.gsub!('.rb', '')
          puts "  -> #{lib}" if GitHooks.verbose
          require lib
        end
      end
    end

    # rubocop:enable CyclomaticComplexity, MethodLength, AbcSize, PerceivedComplexity
  end
end
