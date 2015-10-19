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

      def initialize(type)
        @type     = type
        @only     = nil
        @inverted = false
      end

      def only(*args)
        return @only if args.empty?
        file, line = caller.first.split(':')[0..1]
        @only = args.flatten
        @only.each do |selector|
          if selector.respond_to?(:call) && selector.arity == 0
            fail Error::InvalidLimiterCallable, "Bad #{@type} limiter at #{file}:#{line}; " \
                                                'expected callable to recieve at least one parameter but receives none.'
          end
        end
        self
      end
      alias_method :to, :only

      def except(*args)
        only(*args).tap { invert! }
      end

      def limit(files)
        files.select! do |file|
          match_file(file).tap do |result|
            if GitHooks.debug?
              result = (result ? 'success' : 'failure')
              STDERR.puts "  #{file.path} (#{file.attribute_value(@type).inspect}) was a #{result}"
            end
          end
        end
      end

    private

      def invert!
        @inverted = true
      end

      def match_file(file)
        if @inverted
          Array(@only).none? { |value| file.match(@type, value) }
        else
          Array(@only).any? { |value| file.match(@type, value) }
        end
      end
    end
  end
end
