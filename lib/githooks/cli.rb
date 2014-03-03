require 'thor'

module GitHooks
  module CLI
    autoload :Config, 'githooks/commands/config'

    class Base < Thor
      class_option :verbose, type: :boolean, desc: 'verbose output', default: false
      class_option :debug, type: :boolean, desc: 'debug output', default: false

      # githook attach [--hook <hook1,hookN>] [--script <path> | --path <path>]
      #   --  attaches the listed hooks (or all if none specified) to the githook runner
      #       optionally sets the script XOR path
      desc :attach, 'attach githooks to repository hooks'
      method_option :script, type: :string, desc: 'Path to script to run', default: nil
      method_option :path, type: :string, desc: 'Path to library of tests', default: nil
      method_option :repo, type: :string, desc: 'Path to repo to run tests on', default: Dir.getwd
      method_option :hooks, { # rubocop:disable BracesAroundHashParameters
        type: :array,
        desc: 'Path to repo to run tests on',
        enum: Hook::VALID_PHASES,
        default: Hook::VALID_PHASES
      }
      def attach
        GitHooks.verbose = !!options['verbose']
        GitHooks.debug = !!options['debug']

        if options['script'].nil? && options['path'].nil?
          fail ArgumentError, %q|Neither 'path' nor 'script' were specified - please provide one or the other.|
        elsif options['script'] && options['path']
          fail ArgumentError, %q|Both 'script' and 'path' have been specified. Choose one or the other.|
        end

        Runner.attach(options['repo'], options['hooks'], options['script'] || options['path'])
      end

      # githook dettach [--hook <hook1,hookN>]
      #   --  detaches the listed hooks, or all hooks if none specified
      desc :detach, 'detach githooks from repository hooks'
      method_option :repo, type: :string, desc: 'Path to repo to run tests on', default: Dir.getwd
      method_option :hooks, { # rubocop:disable BracesAroundHashParameters
        type: :array,
        desc: 'Path to repo to run tests on',
        enum: Hook::VALID_PHASES,
        default: Hook::VALID_PHASES
      }
      def detach
        GitHooks.verbose = !!options['verbose']
        GitHooks.debug = !!options['debug']
        Runner.detach(options['repo'], options['hooks'])
      end

      # githook list [--hook <hook1,hook2,hookN>]
      #   --  lists tests for the given hook(s), or all hooks if none specified
      desc :list, 'list tests assigned to given repository hooks'
      method_option :repo, type: :string, desc: 'Path to repo to run tests on', default: Dir.getwd
      def list
        GitHooks.verbose = !!options['verbose']
        GitHooks.debug = !!options['debug']
        Runner.list(options['repo'])
      end

      # githooks run [--hook <hook1,hookN>] [--[un]staged] [--args -- one two three ... fifty]
      #   --  runs the selected hooks (or pre-commit, if none specified) passing
      #       the argument list to the script

      desc :exec, 'Runs the selected hooks, passing the argument list to the script'
      method_option :unstaged, type: :boolean, desc: 'test unstaged files', default: false
      method_option :script, type: :string, desc: 'Path to script to run', default: nil
      method_option :path, type: :string, desc: 'Path to library of tests', default: nil
      method_option :repo, type: :string, desc: 'Path to repo to run tests on', default: Dir.getwd
      method_option :'skip-pre', type: :boolean, desc: 'Skip PreRun Scripts', default: false
      method_option :'skip-post', type: :boolean, desc: 'Skip PostRun Scripts', default: false
      method_option :'skip-bundler', type: :boolean, desc: %Q|Don't load bundler gemfile|, default: false
      method_option :args, type: :array, desc: 'Args to pass to pre/post scripts and main testing script', default: []
      def exec(*args)
        GitHooks.verbose = !!options['verbose']
        GitHooks.debug = !!options['debug']

        ENV['UNSTAGED'] = '1' if options['unstaged']
        GitHooks::Runner.run(options)
      end

      desc :config, 'manage githooks configuration'
      subcommand :config, Config
    end
  end
end
