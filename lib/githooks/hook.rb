require 'delegate'

module GitHooks
  class Hook < DelegatorClass(Hook::Base)

    autoload :PreCommit,        'githooks/hook/pre_commit'
    autoload :PrepareCommitMsg, 'githooks/hook/prepare_commit_msg'
    autoload :CommitMsg,        'githooks/hook/commit_msg'
    autoload :PostCommit,       'githooks/hook/post_commit'
    autoload :ApplypatchMsg,    'githooks/hook/applypatch_msg'
    autoload :PreApplypatch,    'githooks/hook/pre_applypatch'
    autoload :PostApplypatch,   'githooks/hook/post_applypatch'
    autoload :PreRebase,        'githooks/hook/pre_rebase'
    autoload :PostMerge,        'githooks/hook/post_merge'
    autoload :Update,           'githooks/hook/update'
    autoload :PostUpdate,       'githooks/hook/post_update'

    def initialize(type, *args)
      @hook = self.const_get(type.tr('-', '_').camelcase.to_sym).new(*args)
    end

    def __getobj__() @hook; end
  end
end