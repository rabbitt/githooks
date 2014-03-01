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
    extend self

    NORMAL = "\033[0;0m"

    def color(name)
      name = name.to_s
      # return '' unless $stdout.tty? && $stderr.tty?
      return NORMAL if name.match(/norm/)

      light = !!name.to_s.match(/(light|bright)/) ? "1" : "0"
      blink = !!name.to_s.match(/blink/)

      color_code = 30 + case name.to_s
        when /black/, /gray/ then 0
        when /red/ then 1
        when /green/ then 2
        when /yellow/ then 3
        when /blue/ then 4
        when /magenta/,/purple/ then 5
        when /cyan/ then 6
        when /white/ then 7
        else return NORMAL
      end

      "\033[#{light}#{blink ? ';5' : ''};#{color_code}m"
    end

    ['light', 'bright', 'dark', ''].each do |shade|
      ['blink', 'blinking', ''].each do |style|
        %w(black gray red green yellow blue magenta purple cyan white).each do |color|
          name = "#{style}_#{shade}_#{color}".gsub(/(^_+|_+$)/, '').gsub(/_{2,}/, '_')
          const_set(name.upcase, color(name))
          define_method(name) { |text| "#{color(name)}#{text}#{color(:normal)}" }
        end
      end
    end
  end
end

if $0 == __FILE__
  include GitHooks::TerminalColors
  puts send(ARGV.shift, ARGV.join(" ")) unless ARGV.empty?
end
