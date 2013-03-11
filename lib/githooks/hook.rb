require 'singleton'

module GitHooks
  class RegistrationError < StandardError; end
  class Hook
    include Singleton

    def self.method_missing(*args, &block)
      return super unless self.instance.respond_to? args.first
      self.instance.public_send(*args, &block)
    end

    def run_for(hook_name)
      @hooks[hook_name].all? { |hook| hook.run }
    end

    def initialize
      @hooks   = {}
      @hook    = nil
      @section = nil
    end

    def register(hook, &block)
      raise ArgumentError, "Missing required block to #register" unless block_given?
      @hooks[@hook = hook] ||= []
      instance_eval(&block)
      self
    end

    def section(name)
      @hooks[@hook] << (@section = Section.new(name))
      self
    end

    def sections
      @hooks[@hook]
    end

    def exit_on_error(value)
      raise RegistrationError, "#exit_on_error called before section defined" unless @section
      @section.exit_on_error = value
    end

    def perform(title, &block)
      raise RegistrationError, "#perform called before section defined" unless @section
      raise ArgumentError, "Missing required block to #perform" unless block_given?
      @section << Action.new(title, &block)
    end
  end
end