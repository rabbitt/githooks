require 'thor'
require 'pry'

module GitHooks
  module CLI
    autoload :Config, 'githooks/commands/config'

    class Base < Thor
      desc :attach, 'attach githooks to repository hooks'
      def attach
      end

      desc :detach, 'detach githooks from repository hooks'
      def detach
      end

      desc :list, 'list tests assigned to given repository hooks'
      def list
      end

      # githooks run [--hook <hook1,hookN>] [--[un]staged] [--args -- one two three ... fifty]
      #   --  runs the selected hooks (or pre-commit, if none specified) passing
      #       the argument list to the script

      desc :exec, 'Runs the selected hooks, passing the argument list to the script'
      method_option :unstaged, type: :boolean, desc: 'test unstaged files', default: false
      method_option :script, type: :string, desc: 'Path to script to run', default: nil
      method_option :path, type: :string, desc: 'Path to library of tests', default: nil
      method_option :repo, type: :string, desc: 'Path to repo to run tests on', default: Dir.getwd
      def exec(*args)
        ENV['UNSTAGED'] = '1' if options['unstaged']

        repo    = options['repo']
        script  = options['script'] || Repository.config.script
        libpath = options['path']   || Repository.config.path

        if script
          exec script
        elsif libpath
          GitHooks::Runner.load_tests(libpath)
          GitHooks::Runner.start('pre-commit', repo)
        else
          puts "I can't figure out what to run - specify either path or script to give me a hint..."
        end
      end

      desc :config, 'manage githooks configuration'
      subcommand :config, Config
    end
  end
end
