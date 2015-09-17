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

require_relative '../numbers/infinity'

class Array
  def minimum(&_block)
    collection = block_given? ? collect { |obj| yield obj } : self
    collection.inject(Infinity) do |min, num| # rubocop:disable Style/EachWithObject
      min = num < min ? num : min
      min
    end
  end
  alias_method :min, :minimum

  def maximum(&_block)
    collection = block_given? ? collect { |obj| yield obj } : self
    collection.inject(0) do |max, num| # rubocop:disable Style/EachWithObject
      max = num > max ? num : max
      max
    end
  end
  alias_method :max, :maximum
end
