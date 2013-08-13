require 'singleton'

module GitHooker
  class RegistrationError < StandardError; end
  class Hook
    include Singleton

    def self.method_missing(*args, &block)
      return super unless self.instance.respond_to? args.first
      self.instance.send(*args, &block)
    end

    def initialize
      @sections   = []
      @section = nil
    end

    def register(&block)
      raise ArgumentError, "Missing required block to #register" unless block_given?
      instance_eval(&block)
      self
    end

    def run
      @sections.collect { |section| section.run }.all?
    end

    # DSL methods

    def section(name)
      @sections << (@section = Section.new(name))
      self
    end

    def sections
      @sections
    end

    def stop_on_error(value)
      raise RegistrationError, "#stop_on_error called before section defined" unless @section
      @section.stop_on_error = value
    end

    def perform(title, &block)
      raise RegistrationError, "#perform called before section defined" unless @section
      raise ArgumentError, "Missing required block to #perform" unless block_given?
      @section << Action.new(title, &block)
    end
  end
end