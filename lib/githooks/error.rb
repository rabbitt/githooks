module GitHooks
  class Error < StandardError
    class NotAGitRepo < GitHooks::Error; end
    class Registration < GitHooks::Error; end
    class TestsFailed < GitHooks::Error; end
    class AlreadyAttached < GitHooks::Error; end
    class NotAttached < GitHooks::Error; end
  end
end
