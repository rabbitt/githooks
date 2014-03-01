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

require 'delegate'

module GitHooks
  class Section < DelegateClass(Array)
    include TerminalColors

    attr_accessor :name, :actions, :hook
    alias :title :name

    def initialize(name, hook, &block)
      @name    = name.to_s.titleize
      @success = true
      @actions   = []
      @hook    = hook

      instance_eval(&block)

      waiting!
    end

    def actions
      @actions.select { |action| !action.manifest.empty? }
    end
    alias :__getobj__ :actions

    def <<(action) @actions << action; end

    def stop_on_error?() @stop_on_error; end

    def success?() @success; end

    def finished?() @status == :finished; end
    def finished!() @status = :finished; end

    def running?() @status == :running; end
    def running!() @status = :running; end

    def waiting?() @status == :waiting; end
    def waiting!() @status = :waiting; end

    def completed?
      @actions.all? { |action| action.finished? }
    end

    def wait_count()
      @actions.select { |action| action.waiting? }.size
    end

    def name()
      "#{GitHooks::SCRIPT_NAME.camelize} :: #{@name}"
    end

    def colored_name()
      status_colorize name
    end

    def action(title, options = {}, &block)
      raise ArgumentError, "Missing required block to #perform" unless block_given?
      @actions << Action.new(title, self, &block)
      self
    end

    def status_colorize(text)
      finished? && completed? ? (success? ? bright_green(text) : bright_red(text)) : dark_cyan(text)
    end

    def run()
      running!
      begin
        actions.collect { |action|
          @success &= action.run
        }.all?
      ensure
        finished!
      end
    end
  end
end
