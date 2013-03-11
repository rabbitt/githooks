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

    def match_files_on(type = :and, options)
      raise ArgumentError, "options should be a hash" unless options.is_a? Hash
      raise ArgumentError, "Match Filter has invalid selection operator '#{type}' (should be: :or, :and, or :not)" unless [:and, :or, :not].include? type
      (@filters||=[]) << [type, options.to_a]
    end

    def match(check_files)
      @filters.inject([])  {|matches, filter|
        case filter.first
          when :not then @files.reject { |f| @match.all? {|match| match_file(f, *filter[1..-1]) } }
          when :and then @files.select { |f| @match.all? {|match| match_file(f, *filter[1..-1]) } }
          when :or then @files.select { |f| @match.any? {|match| match_file(f, *filter[1..-1]) } }
          else raise ArgumentError, "Match Filter missing required selection operator (:or, :and, or :not)"
        end
      }
    end

    def match_file(file, matchtype, matchvalue)
      case matchtype
        when :name then
          matchvalue.is_a?(Regexp) ? file[:path] =~ matchvalue : file[:path] == matchvalue
        when :type then
          matchvalue.is_a?(Array) ? matchvalue.include?(file[:type]) : matchvalue == file[:type]
        when :mode then
          matchvalue & file[:to][:mode] == matchvalue
        when :sha then
          file[:to][:mode] == matchvalue
        when :score then
          file[:score] == matchvalue
      end
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
