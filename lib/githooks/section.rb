require 'delegate'

module GitHooks
  class Section < DelegateClass(Array)
    include TerminalColors

    attr_reader :name, :status, :actions
    attr_accessor :exit_on_error

    def initialize(name)
      @name          = name
      @state         = :prerun
      @success       = true
      @exit_on_error = false
      @actions       = []
    end

    def __getobj__() @actions; end

    def name()
      unless @success
        bright_red @name
      else
        bright_green @name
      end
    end

    def run()
      @state = :running
      @actions.each do |action|
        @success &= action.run
        return @success if not @success and @exit_on_error
      end
    end
  end
end
