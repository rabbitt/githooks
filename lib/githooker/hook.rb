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

    def register(options = {}, &block)
      raise ArgumentError, "Missing required block to #register" unless block_given?

      phase = (options.delete(:phase) || :any).to_s.to_sym
      unless GitHooker::VALID_PHASES.include? phase
        raise ArgumentError, "Phase must be one of #{GitHooker::VALID_PHASES.join(', ')}"
      end

      instance_eval(&block) unless Repo.match_phase(phase)
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

    def perform(title, options = {}, &block)
      raise RegistrationError, "#perform called before section defined" unless @section
      raise ArgumentError, "Missing required block to #perform" unless block_given?
      @section << Action.new(title, options.delete(:phase), &block)
    end
  end
end