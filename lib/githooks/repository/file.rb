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

module GitHooks
  class Repository::File
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
