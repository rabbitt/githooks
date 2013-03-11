require 'singleton'

module GitHooks
  class RegistrationError < StandardError; end
  class Hook
    include Singleton

    def self.method_missing(*args, &block)
      return super unless self.instance.respond_to? args.first
      self.instance.public_send(*args, &block)
    end

    def run
      @hooks.all? { |hook| hook.run }
    end

    def initialize
      @hooks   = []
      @section = nil
    end

    def register(&block)
      raise ArgumentError, "Missing required block to #register" unless block_given?
      instance_eval(&block)
      self
    end

    def section(name)
      @hooks << (@section = Section.new(name))
      self
    end

    def sections
      @hooks
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