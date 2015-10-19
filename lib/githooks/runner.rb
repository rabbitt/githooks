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
      @repo_path  = Pathname.new(options.delete('repo') || Dir.getwd)
      @repository = Repository.new(@repo_path)
      @hook_path  = acquire_hooks_path(options.delete('hooks-path') || @repository.config.hooks_path || @repository.path)
      @script     = options.delete('script') || @repository.hooks_script
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
        load_tests && start
      else
        puts %q"I can't figure out what to run! Specify either path or script to give me a hint..."
      end

      if options.skip_post
        puts 'Skipping PostRun Executables'
      else
        run_externals('post-run-execute')
      end
    rescue SystemStackError => e
      puts "#{e.class.name}: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
    rescue GitHooks::Error::NotAGitRepo => e
      puts "Unable to find a valid git repo in #{repository}."
      puts 'Please specify path to repository via --repo <path>' if GitHooks::SCRIPT_NAME == 'githooks'
      raise e
    end

    def attach
      entry_path   = Pathname.new(script || hook_path).realdirpath
      hook_phases  = options.hooks || Hook::VALID_PHASES
      bootstrapper = Pathname.new(options.bootstrap).realpath if options.bootstrap

      if entry_path.directory?
        if repository.hooks_path
          fail Error::AlreadyAttached, "Repository [#{repo_path}] already attached to hook path #{repository.hooks_path} - Detach to continue."
        end
        repository.config.set('hooks-path', entry_path)
      elsif entry_path.executable?
        if repository.hooks_script
          fail Error::AlreadyAttached, "Repository [#{repo_path}] already attached to script #{repository.hooks_script}. Detach to continue."
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
        repository.config.remove_section(repo_path: repository.path)
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

        GitHooks.quieted { load_tests(true) }

        Hook::VALID_PHASES.each do |phase|
          next unless Hook.phases[phase]

          puts "  Phase #{phase.camelize}:"

          Hook.phases[phase].limiters.each_with_index do |(type, limiter), limiter_index|
            selector = limiter.only.size > 1 ? limiter.only : limiter.only.first
            printf "    Hook Limiter %d: %s -> %s\n", limiter_index + 1, type, selector.inspect
          end

          Hook.phases[phase].sections.each_with_index do |section, section_index|
            printf "    %d: %s\n", section_index + 1, section.title
            section.actions.each_with_index do |action, action_index|
              section.limiters.each_with_index do |(type, limiter), limiter_index|
                selector = limiter.only.size > 1 ? limiter.only : limiter.only.first
                printf "      Section Limiter %d: %s -> %s\n", limiter_index + 1, type, selector.inspect
              end
              printf "      %d: %s\n", action_index + 1, action.title
              action.limiters.each_with_index do |(type, limiter), limiter_index|
                selector = limiter.only.size > 1 ? limiter.only : limiter.only.first
                printf "        Action Limiter %d: %s -> %s\n", limiter_index + 1, type, selector.inspect
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
      path
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
        $stderr.puts "Hook '#{phase}' not defined - skipping..." if GitHooks.verbose? || GitHooks.debug?
        exit!(0) # exit quickly - no need to hold things up
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
            if action.success?
              printf "    %s %s\n", GitHooks::WARNING_SYMBOL, error.color_warning!
            else
              printf "    %s %s\n", GitHooks::FAILURE_SYMBOL, error
            end
          end

          state_string = action.success? ? GitHooks::SUCCESS_SYMBOL : GitHooks::WARNING_SYMBOL

          action.warnings.each do |warning|
            printf "    %s %s\n", state_string, warning
          end
        end
        puts
      end

      success = false if ENV['GITHOOKS_FORCE_FAIL']

      unless success
        command = case phase
          when /commit/i then 'commit'
          when /push/i then 'push'
          else phase
        end
        $stderr.puts "#{command.capitalize} failed due to errors listed above."
        $stderr.puts "Please fix and attempt your #{command} again."
      end

      exit(success ? 0 : 1)
    end

    def load_tests(skip_bundler = nil)
      skip_bundler = skip_bundler.nil? ? options.skip_bundler : skip_bundler

      hooks_path = @hook_path.dup
      hooks_libs = hooks_path.join('lib')
      hooks_init = (p = hooks_path.join('hooks_init.rb')).exist? ? p : hooks_path.join('githooks_init.rb')
      gemfile    = hooks_path.join('Gemfile')

      GitHooks.hooks_root = hooks_path

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
            if Bundler.instance_variables.include? :@settings
              Bundler.send(:remove_instance_variable, :@settings)
            end
          else
            require 'bundler'
          end
          ::Bundler.require(:default)
        rescue LoadError
          puts %q"Unable to load bundler - please make sure it's installed."
          raise
        rescue ::Bundler::GemNotFound => e
          puts "Error: #{e.message}"
          puts 'Did you bundle install your Gemfile?'
          raise
        end
      end

      $LOAD_PATH.unshift hooks_libs.to_s

      Dir.chdir repo_path

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

      true
    end

    # rubocop:enable CyclomaticComplexity, MethodLength, AbcSize, PerceivedComplexity
  end
end
