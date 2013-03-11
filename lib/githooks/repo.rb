module GitHooks
  module Repo
    extend self

    CHANGE_TYPE_SYMBOLS = {
      :added    => 'A', :copied   => 'C', :deleted  => 'D', :modified => 'M',
      :renamed  => 'R', :retyped  => 'T', :unknown  => 'U', :unmerged => 'X',
      :broken   => 'B', :any      => '*'
    }.freeze

    CHANGE_TYPES = CHANGE_TYPE_SYMBOLS.invert.freeze

    DEFAULT_DIFF_INDEX_OPTIONS = { :staged => true, :ref => 'HEAD' }

  public

    def diff_index(options = {})
      options = DEFAULT_DIFF_INDEX_OPTIONS.merge(options)

      cmd = %w(git diff-index -C -M -B)
      cmd << '--cached' if options[:staged]
      cmd << options.delete(:ref) || 'HEAD'

      %x{ #{cmd.join(' ')} }
    end

    def staged_manifest
      @staged_manifest ||= parse_diff_index_data(diff_index(:staged => true, :ref => 'HEAD'))
    end
    alias :commit_manifest :staged_manifest

    def unstaged_manifest
      @unstaged_manifest ||= parse_diff_index_data(diff_index(:staged => false, :ref => 'HEAD'))
    end

  private

    @filters = []

    def parse_diff_index_data(index)
      index.split(/\n+/).inject({}) do |files,data|
        orig_mode, new_mode, orig_sha, new_sha, change_type, file_path, rename_path = data.split(/\s+/)
        change_type, score = change_type.split(/(\d+)/)
        path = rename_path || file_path

        files[path] = {
          :from  => { :mode => orig_mode, :sha => orig_sha, :path => file_path },
          :to    => { :mode => new_mode, :sha => new_sha, :path => path },
          :type  => CHANGE_TYPES[change_type],
          :score => score.to_i,
          :path  => path
        }; files
      end
    end

  end
end
