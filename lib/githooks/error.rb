module GitHooks
  class Error < StandardError
    class NotAGitRepo < GitHooks::Error; end
    class Registration < GitHooks::Error; end
  end
end
