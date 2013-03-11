require 'singleton'

module GitHooks
  class RegistrationError < StandardError; end
  class Hook
    include Singleton

    def initialize
      @hooks     = {}
      @hook_name = nil
      @section   = nil
    end

    def register(hook_name, &block)
      raise ArgumentError, "Missing required block to #register" unless block_given?
      @hooks[@hook_name = hook_name] ||= []
      instance_eval(&block)
    end

    def section(name)
      @hooks[@hook_name] << (@section = Section.new(name))
    end

    def exit_on_error(value)
      raise RegistrationError, "#exit_on_error called before section defined" unless @section
      @section.exit_on_error = value
    end

    def perform(title, &block)
      raise RegistrationError, "#perform called before section defined" unless @section
      raise ArgumentError, "Missing required block to #perform" unless block_given?
      @section << Action.new(title, block)
  end
end