# encoding: utf-8
module GitHooker
  module TerminalColors
    extend self

    NORMAL = "\033[0;0m"

    MARK_SUCCESS = '✓'
    MARK_FAILURE = 'X'
    MARK_UNKNOWN = '?'

    def color(name)
      return "" unless $stdout.tty? && $stderr.tty?
      return NORMAL if !!name.to_s.match(/norm/)

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

      return "\033[#{light};5;#{color_code}m" if blink
      return "\033[#{light};#{color_code}m"
    end

    ['light', 'bright', 'dark', ''].each do |shade|
      ['blink', 'blinking', ''].each do |style|
        %w(black red green yellow blue magenta purple cyan white).each do |color|
          name = "#{style}_#{shade}_#{color}".gsub(/(^_+|_+$)/, '').gsub(/_{2,}/, '_')
          const_set(name.upcase, color(name))
          define_method(name) { |text| "#{self.color(name)}#{text}#{self.color(:normal)}" }
        end
      end
    end
  end
end

if $0 == __FILE__
  include GitHooker::TerminalColors
  puts send(ARGV.shift, ARGV.join(" ")) unless ARGV.empty?
end