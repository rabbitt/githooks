require 'singleton'
require 'commander'
require 'commander/delegates'
require 'monitor'

module GitHooks
  class CommandRunner < Commander::Runner
    include Singleton

    include Commander::UI
    include Commander::UI::AskForClass

    # rubocop:disable GlobalVars, RescueModifier
    $terminal.wrap_at = HighLine::SystemExtensions.terminal_size.first - 5 rescue 80 if $stdin.tty?
    # rubocop:enable GlobalVars, RescueModifier

    def self.method_missing(method, *args, &block)
      return super unless instance.public_methods.include? method
      instance.public_send(method, *args, &block)
    end

    COMMAND_PATH = GitHooks::LIB_PATH + 'githooks' + 'commands'

    def initialize
      super
      @__register_mutex__ = Monitor.new
      initial_setup
    end

    def register(name, &block)
      @__register_mutex__.synchronize do
        yield add_command(GitHooks::Command.new(name)) if block
        begin
          @commands[name.to_s].load_subordinates
        rescue NoMethodError => e
          puts "failed to load subordinates for :#{name} -> #{e.message}"
          raise e
        end
      end
    end

    def initial_setup
      program :name, Pathname.new($0).basename
      program :version, GitHooks::VERSION
      program :description, 'Utility for managing git hooks.'

      program :help, 'Author', GitHooks::AUTHOR
    end

    def load_commands!
      libpath = GitHooks::LIB_PATH.to_s + '/'
      Dir["#{COMMAND_PATH.to_s}/*.rb"].each do |path|
        path.gsub!(libpath, '').gsub!(/\.rb$/, '').gsub!(%r{^/}, '')
        puts "loading: #{path}"
        require path
      end
    end
  end

  class Command < Commander::Command
    def load_subordinates
      libpath = GitHooks::LIB_PATH.to_s + '/'
      subordinate_path = (CommandRunner::COMMAND_PATH + name)
      Dir["#{subordinate_path}/*.rb"].each do |path|
        path.gsub!(libpath, '').gsub!(/\.rb$/, '').gsub!(%r{^/}, '')
        puts "loading: #{path}"
        require path
      end
      self
    end
  end
end
