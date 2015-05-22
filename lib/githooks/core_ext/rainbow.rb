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

require 'rainbow/ext/string'

module Rainbow
  module Ext
    module String
      module InstanceMethods
        def success!
          color(:green).bright
        end

        def failure!
          color(:red).bright
        end

        def unknown!
          color(:yellow).bright
        end
        alias_method :warning!, :unknown!
      end
    end
  end
end
