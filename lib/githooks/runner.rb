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

require 'fileutils'
require 'githooks/terminal_colors'
require 'shellwords'
require 'thor'

module GitHooks
  module Runner
    extend TerminalColors

    MARK_SUCCESS = '✓'
    MARK_FAILURE = 'X'
    MARK_UNKNOWN = '?'

    def run(options = {}) # rubocop:disable CyclomaticComplexity, MethodLength
      # unfreeze options
      options = Thor::CoreExt::HashWithIndifferentAccess.new(options)

      repo    = options['repo']   ||= Repository.root_path
      script  = options['script'] ||= Repository.instance(repo).config.script
      libpath = options['path']   ||= Repository.instance(repo).config.path
      args    = options['args']   ||= []

      GitHooks.verbose = !!ENV['GITHOOKS_VERBOSE']
      GitHooks.debug   = !!ENV['GITHOOKS_DEBUG']

      if options['skip-pre']
        puts 'Skipping PreRun Executables'
      else
        run_externals('pre-run-execute', repo, args)
      end

      if script && !(options['ignore-script'] || GitHooks.ignore_script)
        command = "#{script} #{Pathname.new($0)} #{Shellwords.join(ARGV)};"
        puts "Kernel#exec(#{command.inspect})" if GitHooks.verbose
        exec(command)
      elsif libpath
        load_tests(libpath, options['skip-bundler'])
        start(options)
      else
        puts 'I can\'t figure out what to run - specify either path or script to give me a hint...'
      end

      if options['skip-post']
        puts 'Skipping PostRun Executables'
      else
        run_externals('post-run-execute', repo, args)
      end
    rescue GitHooks::Error::NotAGitRepo
      puts "Unable to find a valid git repo in #{repo}."
      puts 'Please specify path to repo via --repo <path>' if GitHooks::SCRIPT_NAME == 'githooks'
    end
    module_function :run

    def attach(options = {}) # rubocop:disable CyclomaticComplexity, MethodLength
      repo_path  = options[:repo] || Repository.root_path
      repo_path  = Pathname.new(repo_path) unless repo_path.nil?
      repo_hooks = repo_path + '.git' + 'hooks'

      entry_path = options[:script] || options[:path]

      hook_phases = options[:hooks]
      hook_phases ||= Hook::VALID_PHASES

      bootstrapper = options[:bootstrap]
      bootstrapper = Pathname.new(bootstrapper).realpath unless bootstrapper.nil?
      entry_path   = Pathname.new(entry_path).realdirpath

      repo = Repository.instance(repo_path)

      if entry_path.directory?
        if path = repo.config['path'] # rubocop:disable AssignmentInCondition
          fail Error::AlreadyAttached, "Repository [#{repo_path}] already attached to path #{path} - Detach to continue."
        end
        repo.config.set('path', entry_path)
      elsif entry_path.executable?
        if path = repo.config['script'] # rubocop:disable AssignmentInCondition
          fail Error::AlreadyAttached, "Repository [#{repo_path}] already attached to script #{path}. Detach to continue."
        end
        repo.config.set('script', entry_path)
      else
        fail ArgumentError, "Provided path '#{entry_path}' is neither a directory nor an executable file."
      end

      gitrunner = bootstrapper
      gitrunner ||= SystemUtils.which('githooks-runner')
      gitrunner ||= (GitHooks::BIN_PATH + 'githooks-runner').realpath

      hook_phases.each do |hook|
        hook = (repo_hooks + hook).to_s
        puts "Linking #{gitrunner} -> #{hook}" if GitHooks.verbose
        FileUtils.ln_sf gitrunner.to_s, hook
      end
    end
    module_function :attach

    def detach(repo_path, hook_phases)
      repo_path   ||= Repository.root_path
      repo_hooks    = Pathname.new(repo_path) + '.git' + 'hooks'
      hook_phases ||= Hook::VALID_PHASES

      repo = Repository.instance(repo_path)

      hook_phases.each do |hook|
        next unless (repo_hook = (repo_hooks + hook)).symlink?
        puts "Removing hook '#{hook}' from repository at: #{repo_path}" if GitHooks.verbose
        FileUtils.rm_f repo_hook
      end

      active_hooks = Hook::VALID_PHASES.select { |hook| (repo_hooks + hook).exist? }

      if active_hooks.empty?
        puts 'All hooks detached. Removing configuration section.'
        repo.config.remove_section(repo_path: repo_path)
      else
        puts "Keeping configuration for active hooks: #{active_hooks.join(', ')}"
      end
    end
    module_function :detach

    def list(repo_path) # rubocop:disable Style/CyclomaticComplexity, Style/MethodLength
      repo_path  ||= Pathname.new(Repository.root_path)

      repo = Repository.instance(repo_path)
      script  = repo.config.script
      libpath = repo.config.path

      unless script || libpath
        fail Error::NotAttached, 'Repository currently not configured. Usage attach to setup for use with githooks.'
      end

      if (executables = repo.config.pre_run_execute).size > 0
        puts 'PreRun Executables (in execution order):'
        executables.each do |exe|
          puts "  #{exe}"
        end
        puts
      end

      if script
        puts 'Main Test Script:'
        puts "  #{script}"
        puts
      end

      if libpath
        puts 'Main Testing Library with Tests (in execution order):'
        puts '  Tests loaded from:'
        puts "    #{libpath}"
        puts

        SystemUtils.quiet { load_tests(libpath, true) }

        %w{ pre-commit commit-msg }.each do |phase|
          next unless Hook.phases[phase]

          puts "  Phase #{phase.camelize}:"
          Hook.phases[phase].sections.each_with_index do |section, section_index|
            printf "    %3d: %s\n", section_index + 1, section.title
            section.all.each_with_index do |action, action_index|
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

      if (executables = repo.config.post_run_execute).size > 0
        puts 'PostRun Executables (in execution order):'
        executables.each do |exe|
          puts "  #{exe}"
        end
        puts
      end
    rescue GitHooks::Error::NotAGitRepo
      puts "Unable to find a valid git repo in #{repo}."
      puts 'Please specify path to repo via --repo <path>' if GitHooks::SCRIPT_NAME == 'githooks'
    end
    module_function :list

  private

    def run_externals(which, repo_path, args)
      Repository.instance(repo_path).config[which].all? do |executable|
        command = SystemUtils::Command.new(File.basename(executable), path: executable)

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
      end || fail(TestsFailed, "Failed #{which.camelize} executables - giving up")
    end
    module_function :run_externals

    def start(options = {}) # rubocop:disable Style/CyclomaticComplexity, Style/MethodLength
      phase = options[:hook] || GitHooks.hook_name || 'pre-commit'
      puts "PHASE: #{phase}" if GitHooks.debug

      if (active_hook = Hook.phases[phase])
        active_hook.args            = options.delete(:args)
        active_hook.staged          = options.delete(:staged)
        active_hook.untracked       = options.delete(:untracked)
        active_hook.tracked         = options.delete(:tracked)
        active_hook.repository_path = options.delete(:repo)
      else
        fail Error::InvalidPhase, "Hook '#{phase}' is not defined - have you registered any tests for this hook yet?"
      end

      success        = active_hook.run
      section_length = active_hook.sections.max { |s| s.title.length }
      sections       = active_hook.sections.select { |section| !section.actions.empty? }

      sections.each do |section|
        hash_tail_length = (section_length - section.title.length)
        printf "===== %s %s===== (%ds)\n", section.colored_name(phase), ('=' * hash_tail_length), section.benchmark

        section.actions.each_with_index do |action, index|
          printf "  %d. [ %s ] %s (%ds)\n", (index + 1), action.state_symbol, action.colored_title, action.benchmark

          action.errors.each do |error|
            printf "    %s %s\n", color_bright_red(MARK_FAILURE), error
          end

          state_string = ( action.success? ? color_bright_green(MARK_SUCCESS) : color_bright_yellow(MARK_UNKNOWN))
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
    module_function :start

    def load_tests(path, skip_bundler = false) # rubocop:disable MethodLength,Style/CyclomaticComplexity
      hooks_root = Pathname.new(path).realpath
      hooks_path = (p = (hooks_root + 'hooks')).exist? ? p : (hooks_root + '.hooks')
      hooks_libs = hooks_root + 'libs'
      gemfile    = hooks_root + 'Gemfile'

      if gemfile.exist? && !skip_bundler
        puts "loading Gemfile from: #{gemfile}" if GitHooks.verbose

        begin
          ENV['BUNDLE_GEMFILE'] = (hooks_root + 'Gemfile').to_s

          # stupid RVM polluting my environment without asking via it's
          # executable-hooks gem preloading bundler. hence the following ...
          if defined? Bundler
            [:@bundle_path, :@configured, :@definition, :@load].each do |var|
              Bundler.instance_variable_set(var, nil)
            end
            # bundler tests for @settings using defined? - which means we need
            # to forcibly remove it.
            Bundler.send(:remove_instance_variable, :@settings)
          else
            require 'bundler'
          end
          Bundler.require(:default)
        rescue LoadError
          puts %Q|Unable to load bundler - please make sure it's installed.|
          raise # rubocop:disable SignalException
        rescue Bundler::GemNotFound => e
          puts "Error: #{e.message}"
          puts 'Did you bundle install your Gemfile?'
          raise # rubocop:disable SignalException
        end
      end

      $LOAD_PATH.unshift hooks_libs.to_s

      Dir["#{hooks_path}/**/*.rb"].each do |lib|
        lib.gsub!('.rb', '')
        puts "Loading: #{lib}" if GitHooks.verbose
        require lib
      end
    end
    module_function :load_tests
  end
end
