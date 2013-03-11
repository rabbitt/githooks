require 'delegate'

module GitHooker
  class Section < DelegateClass(Array)
    include TerminalColors

    attr_reader :name, :status
    attr_accessor :exit_on_error

    attr_reader :actions
    alias :__getobj__ :actions

    def initialize(name)
      @name          = name.to_s.titleize
      @success       = true
      @exit_on_error = false
      @actions       = []
    end

    def name()
      unless @success
        bright_red @name
      else
        bright_green @name
      end
    end

    def run()
      @actions.each do |action|
        @success &= action.run
        return false if not @success and @exit_on_error
      end
      return @success
    end
  end
end
