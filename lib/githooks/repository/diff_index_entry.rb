require 'ostruct'
require 'pathname'
require 'githooks/repository/file'

module GitHooks
  class Repository
    class DiffIndexEntry < OpenStruct
      DIFF_STRUCTURE_REGEXP = %r{
        ^:
        (?<original_mode>\d+)\s
        (?<new_mode>\d+)\s
        (?<original_sha>[a-f\d]+)\.*\s
        (?<new_sha>[a-f\d]+)\.*\s
        (?<change_type>.)
        (?:(?<score>\d+)?)\s
        (?<file_path>\S+)\s?
        (?<rename_path>\S+)?
      }xi unless defined? DIFF_STRUCTURE_REGEXP

      def self.from_file_path(path, tracked = false)
        path = Pathname.new(path)
        entry_line = sprintf(":%06o %06o %040x %040x %s\t%s",
                             0, path.stat.mode, 0, 0, (tracked ? '^' : '?'), path.to_s)
        new(entry_line)
      end

      def initialize(entry)
        unless entry =~ DIFF_STRUCTURE_REGEXP
          fail ArgumentError, "Unable to parse incoming diff entry data: #{entry}"
        end
        super parse_data(entry)
      end

      def parse_data(entry) # rubocop:disable MethodLength
        data = Hash[
          DIFF_STRUCTURE_REGEXP.names.collect(&:to_sym).zip(
            entry.match(DIFF_STRUCTURE_REGEXP).captures
          )
        ]

        {
          from:  FileState.new(
            data[:original_mode].to_i(8),
            data[:original_sha],
            data[:file_path].nil? ? nil : Pathname.new(data[:file_path])
          ),
          to:    FileState.new(
            data[:new_mode].to_i(8),
            data[:new_sha],
            data[:rename_path].nil? ? nil : Pathname.new(data[:rename_path])
          ),
          type:  Repository::CHANGE_TYPES[data[:change_type]],
          score: data[:score].to_i
        }
      end

      def to_repo_file
        Repository::File.new(self)
      end

      class FileState
        attr_reader :mode, :sha, :path

        def initialize(mode, sha, path)
          @mode, @sha, @path = mode, sha, path
        end

        def inspect
          "#<#{self.class.name.split('::').last} mode=#{mode.to_s(8)} path=#{path.to_s.inspect} sha=#{sha.inspect}>"
        end

        def to_path
          Pathname.new(@path)
        end
      end
    end
  end
end
