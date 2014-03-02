# encoding: utf-8
=begin
Copyright (C) 2013 Carl P. Corliss

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
=end

require 'ostruct'
require 'singleton'
require 'open3'

module GitHooks
  class Repository
    CHANGE_TYPE_SYMBOLS = {
      added:    'A', copied:   'C',
      deleted:  'D', modified: 'M',
      renamed:  'R', retyped:  'T',
      unknown:  'U', unmerged: 'X',
      broken:   'B', any:      '*'
    }.freeze

    CHANGE_TYPES = CHANGE_TYPE_SYMBOLS.invert.freeze

    DEFAULT_DIFF_INDEX_OPTIONS = { staged: true, ref: 'HEAD' }

    @__instance__ = {}
    @__mutex__    = Mutex.new
    def self.instance(path = Dir.getwd)
      path = Pathname.new(path).realpath
      return @__instance__[path] if @__instance__[path]

      @__mutex__.synchronize do
        return @__instance__[path] if @__instance__[path]
        @__instance__[path] = new(path)
      end
    end

    def self.method_missing(method, *args, &block)
      return super unless instance.public_methods.include? method
      instance.public_send(method, *args, &block)
    end

    attr_reader :root_path

    def initialize(path = GitHooks::SCRIPT_DIR)
      @root_path = get_root_path(path)
    end
    protected :initialize

    def git_command(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      path = options.delete(:path) || @root_path

      command = Shellwords.shelljoin(['git', *args].flatten)
      o, e, s = Open3.capture3(%Q{ cd #{path} ; #{command} })
      OpenStruct.new(output: o.strip, error: e.strip, status: s)
    end

    def get_root_path(path)
      git_command(%w( rev-parse --show-toplevel), path: path).tap do |result|
        unless result.status.success? && result.output !~ /not a git repository/i
          fail Error::NotAGitRepo, "Unable to find a valid git repo in #{path}"
        end
      end.output.strip
    end

    def stash
      git_command(%w( stash -q --keep-index -a)).status.success?
    end

    def unstash
      git_command(%w(stash pop -q)).status.success?
    end

    def use_unstaged?
      ENV['UNSTAGED']
    end

    def diff_index(options = {})
      options = DEFAULT_DIFF_INDEX_OPTIONS.merge(options)

      cmd = %w(diff-index -C -M -B)
      cmd << '--cached' if options[:staged]
      cmd << options.delete(:ref) || 'HEAD'

      git_command(*cmd).output.strip
    end

    def manifest(unstaged = false)
      unstaged || use_unstaged? ? unstaged_manifest : staged_manifest
    end

    def staged_manifest
      parse_diff_index_data(diff_index(staged: true, ref: 'HEAD'))
    end
    alias_method :commit_manifest, :staged_manifest

    def unstaged_manifest
      parse_diff_index_data(diff_index(staged: false, ref: 'HEAD'))
    end

    def match_files_on(options)
      fail ArgumentError, 'options should be a hash' unless options.is_a? Hash
      match(manifest, options.to_a)
    end

    def while_stashed
      fail ArgumentError, 'Missing required block' unless block_given?
      begin
        stash
        return yield
      ensure
        unstash
      end
    end

    def run_while_stashed(cmd)
      while_stashed { system(cmd) }
      $? == 0
    end

    def parse_diff_index_data(index)
      index.split(/\n+/).collect { |data| Repository::File.new(data) }
    end
    private :parse_diff_index_data

    class Limiter
      attr_reader :type, :action
      def initialize(type, options = {})
        @type   = type
        @only   = options.delete(:only) || options.delete(:to)
      end

      def only(*args)
        @only = args.flatten
      end
      alias_method :to, :only

      def limit(files)
        # binding.pry
        files.select! { |file| match_file(file, @only) }
      end

      def match_file(file, match_value)
        if match_value.is_a? Array
          match_value.any? { |value| file.match(@type, value) }
        else
          file.match(@type, match_value)
        end
      end
    end

    class File
      attr_reader :from, :to, :type, :score, :path, :name

      def initialize(data)
        orig_mode, new_mode, orig_sha, new_sha, change_type, file_path, rename_path = data.split(/\s+/)
        change_type, score = change_type.split(/(\d+)/)
        path = rename_path || file_path

        @path  = Pathname.new(path)
        @name  = @path.basename.to_s
        @from  = OpenStruct.new(mode: orig_mode[1..-1].to_i, sha: orig_sha, path: file_path)
        @to    = OpenStruct.new(mode: new_mode.to_i, sha: new_sha, path: path)
        @type  = Repository::CHANGE_TYPES[change_type]
        @score = score.to_i
      end

      # rubocop:disable CyclomaticComplexity
      def attribute_value(attribute)
        case attribute
          when :name then name.to_s
          when :path then path.to_s
          when :type then type
          when :mode then to.mode
          when :sha then to.sha
          when :score then score
          else fail ArgumentError,
                    "Invalid attribute type '#{attribute}' - expected: :name, :path, :type, :mode, :sha, or :score"
        end
      end

      def match(type, _match)
        value = attribute_value(type)
        return _match.call(value) if _match.respond_to? :call

        case type
          when :name  then _match.is_a?(Regexp) ? value =~ _match : value == _match
          when :path  then _match.is_a?(Regexp) ? value =~ _match : value == _match
          when :type  then _match.is_a?(Array) ? _match.include?(value) : _match == value
          when :mode  then _match & value == _match
          when :sha   then _match == value
          when :score then _match == value
        end
      end
      # rubocop:enable CyclomaticComplexity

      def fd
        case type
          when :deleted, :deletion then nil
          else @path.open
        end
      end

      def realpath
        case type
          when :deleted, :deletion then @path
          else @path.realpath
        end
      end

      def contains?(string_or_regexp)
        if string_or_regexp.is_a?(Regexp)
          contents =~ string_or_regexp
        else
          contents.include? string_or_regexp
        end
      end

      def grep(regexp)
        lines(true).select_with_index { |line| line =~ regexp }
      end

      def contents
        return unless fd
        fd.read
      end

      def lines(strip_newlines = false)
        return [] unless fd
        strip_newlines ? fd.readlines.collect(&:chomp!) : fd.readlines
      end
    end
  end
end
