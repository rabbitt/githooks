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

require 'delegate'

module GitHooks
  class Repository
    # allow for reloading of class
    unless defined? DiffIndexEntryDelegateClass
      DiffIndexEntryDelegateClass = DelegateClass(DiffIndexEntry)
    end

    class File < DiffIndexEntryDelegateClass
      attr_reader :repo, :file

      private :repo
      protected :file

      alias_method :__getobj__, :file

      def initialize(repo, entry)
        @repo = repo
        @file = entry
      end

      def inspect
        attributes = [:name, :path, :type, :mode, :sha, :score].collect do |name|
          "#{name}=#{attribute_value(name).inspect}"
        end
        "#<#{self.class.name} #{attributes.join(' ')} >"
      end

      def path
        to.path || from.path
      end

      def full_path
        repo.path.join(path)
      end

      def name
        path.basename.to_s
      end

      def attribute_value(attribute) # rubocop:disable Metrics/CyclomaticComplexity
        case attribute
          when :name then name
          when :path then path.to_s
          when :type then type
          when :mode then to.mode
          when :sha then to.sha
          when :score then score
          else fail ArgumentError,
                    "Invalid attribute type '#{attribute}' - expected: :name, :path, :type, :mode, :sha, or :score"
        end
      end

      def match(type, selector)
        if selector.respond_to? :call
          match_callable(type, selector)
        else
          match_type(type, selector)
        end
      end

      # rubocop:disable ElseAlignment, IndentationWidth
      def match_callable(type, selector)
        value = attribute_value(type)

        case (arity = selector.arity)
          when 0 then fail ArgumentError, 'limiter recieves no parameters'
          when -4..-1, 3 then selector.call(value, type, self)
          when 1 then selector.call(value)
          when 2 then selector.call(value, type)
        else
          fail ArgumentError, 'expected limiter to receive at most 3 parameters, ' \
                               "but it receives #{arity}"
        end
      end
      # rubocop:enable ElseAlignment, IndentationWidth

      def match_type(type, selector) # rubocop:disable AbcSize,CyclomaticComplexity
        value = attribute_value(type)
        case type
          when :name  then selector.is_a?(Regexp) ? value =~ selector : value == selector
          when :path  then selector.is_a?(Regexp) ? value =~ selector : value == selector
          when :type  then [*selector].include?(:any) ? true : [*selector].include?(value)
          when :mode  then selector & value == selector
          when :sha   then selector == value
          when :score then selector == value
        end
      end

      def fd
        case type
          when :deleted, :deletion then nil
          else full_path.open
        end
      end

      def realpath
        case type
          when :deleted, :deletion then path
          else path.realpath
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
        lines(true).select_with_index { |line|
          line =~ regexp
        }.collect { |num, line|
          [num + 1, line] # line numbers start from 1, not 0
        }
      end

      def contents
        return unless fd
        fd.read
      end

      def lines(strip_newlines = false)
        return [] unless fd
        strip_newlines ? fd.readlines.collect(&:chomp!) : fd.readlines
      end

      def eql?(other)
        path.to_s == other.path.to_s
      end

      def hash
        path.to_s.hash
      end

      def <=>(other)
        path.to_s <=> other.path.to_s
      end

      def ==(other)
        path.to_s == other.path.to_s
      end
    end
  end
end
