module Process
  class Status
    def failed?
      !success?
    end
    alias_method :fail?, :failed?
    alias_method :failure?, :failed?
  end
end
