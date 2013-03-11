require 'ostruct'

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
      parse_diff_index_data(diff_index(:staged => true, :ref => 'HEAD'))
    end
    alias :commit_manifest :staged_manifest

    def unstaged_manifest
      parse_diff_index_data(diff_index(:staged => false, :ref => 'HEAD'))
    end

    def match_files_on(options)
      raise ArgumentError, "options should be a hash" unless options.is_a? Hash
      match(ENV['UNSTAGED'] ? unstaged_manifest : staged_manifest, options.to_a)
    end

    # returns the intersection of all file filters
    def match(manifest_files, filters)
      manifest_files.tap { |files|
        filters.each {|type, value| files.select! { |name, data| match_file(data, type, value) } }
      }.values
    end

    def match_file(file, matchtype, matchvalue)
      attr_value = case matchtype
        when :name then file.path
        when :type then file.type
        when :mode then file.to.mode
        when :sha then file.to.sha
        when :score then file.score
        else raise ArgumentError, "Invalid match type '#{matchtype}' - expected one of: :name, :type, :mode, :sha, or :score"
      end

      return matchvalue.call(attr_value) if matchvalue.respond_to? :call

      case matchtype
        when :name then
          matchvalue.is_a?(Regexp) ? attr_value =~ matchvalue : attr_value == matchvalue
        when :type then
          matchvalue.is_a?(Array) ? matchvalue.include?(attr_value) : matchvalue == attr_value
        when :mode then
          matchvalue & attr_value == matchvalue
        when :sha then
          attr_value == matchvalue
        when :score then
          attr_value == matchvalue
      end
    end


  private

    @filters = []

    def parse_diff_index_data(index)
      index.split(/\n+/).inject({}) do |files,data|
        orig_mode, new_mode, orig_sha, new_sha, change_type, file_path, rename_path = data.split(/\s+/)
        change_type, score = change_type.split(/(\d+)/)
        path = rename_path || file_path

        files[path] = OpenStruct.new({
          :from  => OpenStruct.new({ :mode => orig_mode[1..-1].to_i, :sha => orig_sha, :path => file_path }),
          :to    => OpenStruct.new({ :mode => new_mode.to_i, :sha => new_sha, :path => path }),
          :type  => CHANGE_TYPES[change_type],
          :score => score.to_i,
          :path  => path
        }); files
      end
    end

  end
end
