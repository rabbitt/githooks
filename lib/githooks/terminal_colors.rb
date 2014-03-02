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

module GitHooks
  module TerminalColors
    NORMAL = "\033[0;0"

    REGEX_COLOR_MAP = {
      /(black|gr[ae]y)/  => 30,
      /red/              => 31,
      /green/            => 32,
      /yellow/           => 33,
      /blue/             => 34,
      /(magenta|purple)/ => 35,
      /cyan/             => 36,
      /white/            => 37
    }

    def color(name)
      # return '' unless $stdout.tty? && $stderr.tty?
      light = !!name.match(/(light|bright)/) ? '1' : '0'
      blink = !!name.match(/blink/) ? ';5' : ''

      color_code = REGEX_COLOR_MAP.find { |key, code| name =~ key }
      color_code = color_code ? color_code.last : NORMAL

      "\033[#{light}#{blink};#{color_code}m"
    end
    module_function :color

    ['light', 'bright', 'dark', ''].each do |shade|
      ['blinking', ''].each do |style|
        %w(black gray red green yellow blue magenta purple cyan white).each do |color|
          name1 = "color_#{style}_#{shade}_#{color}".gsub(/(^_+|_+$)/, '').gsub(/_{2,}/, '_')
          name2 = "color_#{style}_#{shade}#{color}".gsub(/(^_+|_+$)/, '').gsub(/_{2,}/, '_')
          [name1, name2].each do |name|
            unless const_defined? name.upcase
              const_set(name.upcase, color(name))
              define_method(name) { |text| "#{color(name)}#{text}#{color(:normal)}" }
              module_function name.to_sym
            end
          end
        end
      end
    end
  end
end
