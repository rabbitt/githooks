require 'delegate'

module GitHooker
  class Section < DelegateClass(Array)
    include TerminalColors

    attr_accessor :stop_on_error
    alias :__getobj__ :actions

    def initialize(name)
      @name          = name.to_s.titleize
      @success       = true
      @stop_on_error = false
      @actions       = []

      waiting!
    end

    def actions
      @actions.collect { |action| Repo.match_phase(action.phase) }
    end

    def stop_on_error?() @stop_on_error; end

    def success?() @success; end

    def finished?() @status == :finished; end
    def finished!() @status = :finished; end

    def running?() @status == :running; end
    def running!() @status = :running; end

    def waiting?() @status == :waiting; end
    def waiting!() @status = :waiting; end

    def completed?
      @actions.all? { |action| action.finished? }
    end

    def wait_count()
      @actions.select { |action| action.waiting? }.size
    end

    def name()
      "#{GitHooker::SCRIPT_NAME.camelize} :: #{@name}"
    end

    def colored_name()
      status_colorize name
    end

    def status_colorize(text)
      finished? && completed? ? (success? ? bright_green(text) : bright_red(text)) : dark_cyan(text)
    end

    def run()
      running!
      if stop_on_error?
        @actions.all? { |action| @success &= action.run }
      else
        @actions.collect { |action| @success &= action.run }.all?
      end.tap { finished! }
    end
  end
end
