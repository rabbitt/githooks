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
  class Repository::Limiter
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
end
