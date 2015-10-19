module GitHooks
  class Error < StandardError
    class CommandExecutionFailure < GitHooks::Error; end
    class NotAGitRepo < GitHooks::Error; end
    class Registration < GitHooks::Error; end
    class TestsFailed < GitHooks::Error; end
    class AlreadyAttached < GitHooks::Error; end
    class NotAttached < GitHooks::Error; end
    class InvalidPhase < GitHooks::Error; end
    class InvalidLimiterCallable < GitHooks::Error; end
    class RemoteNotSet < GitHooks::Error
      attr_accessor :branch
    end
  end
end
