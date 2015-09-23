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

module GitHooks
  class Repository
    class Limiter
      attr_reader :type, :only

      def initialize(type, options = {})
        @type     = type
        @only     = options.delete(:only) || options.delete(:to)
        @inverted = false
      end

      def only(*args)
        return @only if args.empty?
        @only = args.flatten
        self
      end
      alias_method :to, :only

      def inverted
        @inverted = true
      end
      alias_method :invert, :inverted

      def limit(files)
        files.select! do |file|
          match_file(file, @only).tap do |result|
            if GitHooks.debug?
              result = (result ? 'success' : 'failure')
              STDERR.puts "  #{file.path} (#{file.attribute_value(@type).inspect}) was a #{result}"
            end
          end
        end
      end

    private

      def match_file(file, match_value)
        if @inverted
          [*match_value].none? { |value| file.match(@type, value) }
        else
          [*match_value].any? { |value| file.match(@type, value) }
        end
      end
    end
  end
end
