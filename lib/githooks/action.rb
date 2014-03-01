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

require 'stringio'
require 'open3'

module GitHooks
  class Action
    include TerminalColors

    attr_reader :title, :errors, :warnings

    def initialize(title, section, block)
      @title    = title
      @filters  = []
      @success  = true
      @errors   = []
      @warnings = []
      @on       = nil
      @section  = section

      instance_eval(&block)

      waiting!
    end

    def manifest
      section.hook.manifest.filter(@filters)
    end

    def colored_title()
      status_colorize title
    end

    def state_symbol
      symbol = finished? ? (success? ? "✓" : 'X') : '?'
      status_colorize symbol
    end

    def success?() @success; end

    def finished?() @status == :finished; end
    def finished!() @status = :finished; end

    def running?() @status == :running; end
    def running!() @status = :running; end

    def waiting?() @status == :waiting; end
    def waiting!() @status = :waiting; end

    def status_colorize(text)
      finished? ? (success? ? bright_green(text) : bright_red(text)) : dark_cyan(text)
    end

    def run
      warnings, errors = StringIO.new, StringIO.new
      begin
        running!
        $stdout, $stderr = warnings, errors
        @success &= @action.call
        return @success
      ensure
        @errors = errors.tap {|e| e.rewind}.read.split(/\n(?:[\t ]*)/)
        @warnings = warnings.tap {|w| w.rewind}.read.split(/\n(?:[\t ]*)/)
        $stdout, $stderr = STDOUT, STDERR
        finished!
      end
    end

    def method_missing(method, *args, &block)
      return super unless command = section.hook.find_command(method)
      run_command(command, *args, &block)
    end

    # DSL Methods

    def args() ARGV.dup; end

    def limit(what)
      @filters << Repository::Limiter.new(what, self)
    end

    def on_each_file(&block)
      @on = -> { manifest.collect { |file| block.call(fall) }.all? }
    end

    def on_all_files(&block)
      @on = ->() { block.call manifest }
    end

    private

    def run_command(command, *args, &block)
      options = args.extract_options
      prefix  = options.delete(:prefix)

      command.call(*args, &block).tap { |res|
        res.output.split(/\n/).each do |line|
          $stdout.puts prefix ? "#{prefix}: #{line}" : line
        end

        res.error.split(/\n/).each do |line|
          $stderr.puts prefix ? "#{prefix}: #{line}" : line
        end
      }.status.success?
    end
  end
end
