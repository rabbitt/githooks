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

require_relative '../array/extract_options'

class String
  def strip_empty_lines!
    replace(strip_empty_lines)
  end

  def strip_empty_lines
    split(/\n/).reject { |s| s !~ /\S/ }.join("\n")
  end

  def strip_non_printable!
    replace(strip_non_printable)
  end

  def strip_non_printable
    gsub(/[^[:print:] \n\t\x1b]/, '')
  end

  def strip_colors!
    replace(strip_colors)
  end

  def strip_colors
    gsub(/\x1b\[\d+(?:;\d+)?m/, '')
  end

  def sanitize!(*methods)
    options = methods.extract_options!

    map = {
      strip:         :strip!,
      empty_lines:   :strip_empty_lines!,
      non_printable: :strip_non_printable!,
      colors:        :strip_colors!
    }

    methods = map.keys if methods.empty? || methods.include?(:all)
    methods -= Array(options.delete(:except)) if options[:except]

    methods.collect(&:to_sym).each do |method|
      send(map[method]) if map[method]
    end

    self
  end

  def sanitize(*methods)
    dup.sanitize!(*methods)
  end
end
