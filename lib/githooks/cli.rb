require 'thor'
require_relative 'hook'
require_relative 'runner'

module GitHooks
  module CLI
    autoload :Config, 'githooks/cli/config'

    # rubocop:disable AbcSize
    class Base < Thor
      class_option :verbose, aliases: '-v', type: :boolean, desc: 'verbose output', default: false
      class_option :debug, aliases: '-d', type: :boolean, desc: 'debug output', default: false

      desc :version, 'display version information'
      def version
        puts "GitHooks: #{GitHooks::VERSION}"
        puts "Git     : #{%x{git --version | grep git}.split(/\s+/).last}"
        puts "Bundler : #{Bundler::VERSION}"
        puts "Ruby    : #{RUBY_ENGINE} #{RUBY_VERSION}p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE})"
      end

      # githook attach [--hook <hook1,hookN>] [--script <path> | --path <path>] [--bootstrap <path>]
      #   --  attaches the listed hooks (or all if none specified) to the githook runner
      #       optionally sets the script XOR path
      desc :attach, 'attach githooks to repository hooks'
      method_option :bootstrap, type: :string, desc: 'Path to bootstrap script', default: nil
      method_option :script, aliases: '-s', type: :string, desc: 'Path to script to run', default: nil
      method_option :'hooks-path', aliases: '-p', type: :string, desc: 'Path to library of tests', default: nil
      method_option :repo, aliases: '-r', type: :string, desc: 'Path to repo to run tests on', default: Dir.getwd
      method_option :hooks, { # rubocop:disable BracesAroundHashParameters
        type: :array,
        desc: 'hooks to attach',
        enum: Hook::VALID_PHASES,
        default: Hook::VALID_PHASES
      }
      def attach
        GitHooks.verbose = !!options['verbose']
        GitHooks.debug = !!options['debug']

        unless options['script'] || options['hooks-path']
          fail ArgumentError, %q"Neither 'path' nor 'script' were specified - please provide at least one."
        end

        Runner.new(options.dup).attach
      end

      # githook dettach [--hook <hook1,hookN>]
      #   --  detaches the listed hooks, or all hooks if none specified
      desc :detach, 'detach githooks from repository hooks'
      method_option :repo, aliases: '-r', type: :string, desc: 'Path to repo to run tests on', default: Dir.getwd
      method_option :hooks, { # rubocop:disable BracesAroundHashParameters
        type: :array,
        desc: 'Path to repo to run tests on',
        enum: Hook::VALID_PHASES,
        default: Hook::VALID_PHASES
      }
      def detach
        GitHooks.verbose = !!options['verbose']
        GitHooks.debug = !!options['debug']
        Runner.new(options.dup).detach(options['hooks'])
      end

      # githook list [--hook <hook1,hook2,hookN>]
      #   --  lists tests for the given hook(s), or all hooks if none specified
      desc :list, 'list tests assigned to given repository hooks'
      method_option :repo, aliases: '-r', type: :string, desc: 'Path to repo to run tests on', default: Dir.getwd
      def list
        GitHooks.verbose = !!options['verbose']
        GitHooks.debug = !!options['debug']
        Runner.new(options.dup).list
      end

      # githooks execute [--[no-]staged] [--tracked] [--untracked] [--args -- one two three ...]
      #   --  runs the selected hooks (or pre-commit, if none specified) passing
      #       the argument list to the script

      desc :execute, 'Runs the selected hooks, passing the argument list to the script'
      method_option :staged, aliases: '-S', type: :boolean, desc: 'test staged files (disabled if unstaged, tracked or untracked set)', default: true
      method_option :unstaged, aliases: '-U', type: :boolean, desc: 'test unstaged files', default: false
      method_option :tracked, aliases: '-A', type: :boolean, desc: 'test tracked files', default: false
      method_option :untracked, aliases: '-T', type: :boolean, desc: 'test untracked files', default: false
      method_option :script, aliases: '-s', type: :string, desc: 'Path to script to run', default: nil
      method_option :'hooks-path', aliases: '-p', type: :string, desc: 'Path to library of tests', default: nil
      method_option :repo, aliases: '-r', type: :string, desc: 'Path to repo to run tests on', default: Dir.getwd
      method_option :'skip-pre', type: :boolean, desc: 'Skip PreRun Scripts', default: false
      method_option :'skip-post', type: :boolean, desc: 'Skip PostRun Scripts', default: false
      method_option :'skip-bundler', type: :boolean, desc: %q"Don't load bundler gemfile", default: false
      method_option :hook, type: :string, enum: Hook::VALID_PHASES, desc: 'Hook to run', default: 'pre-commit'
      method_option :args, type: :array, desc: 'Args to pass to pre/post scripts and main testing script', default: []
      def execute(hooks = [])
        GitHooks.verbose = options['verbose']
        GitHooks.debug = options['debug']

        opts = options.dup

        if opts['tracked'] || opts['untracked'] || opts['unstaged']
          opts['staged'] = false
        end

        opts['skip-bundler'] ||= !!ENV['GITHOOKS_SKIP_BUNDLER']

        opts['hook'] = hooks unless hooks.empty?

        Runner.new(opts).run
      end

      desc :config, 'manage githooks configuration'
      subcommand :config, Config
    end
  end
end
