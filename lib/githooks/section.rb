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

    attr_reader :name, :hook, :success
    alias_method :title, :name
    alias_method :success?, :success

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
    alias_method :__getobj__, :actions

    def <<(action)
      @actions << action
    end

    %w(finished running waiting).each do |method|
      define_method(:"#{method}?") { @status == method.to_sym }
      define_method(:"#{method}!") { @status = method.to_sym }
    end

    def completed?
      @actions.all? { |action| action.finished? }
    end

    def wait_count
      @actions.select { |action| action.waiting? }.size
    end

    def name(phase = GitHooks::HOOK_NAME)
      phase = (phase || GitHooks::HOOK_NAME).to_s.gsub('-', '_').camelize
      "#{phase} :: #{@name}"
    end

    def colored_name(phase = GitHooks::HOOK_NAME)
      status_colorize name(phase)
    end

    def action(title, options = {}, &block)
      fail ArgumentError, 'Missing required block to #perform' unless block_given?
      @actions << Action.new(title, self, &block)
      self
    end

    def status_colorize(text)
      if finished? && completed?
        success? ? color_bright_green(text) : color_bright_red(text)
      else
        color_dark_cyan(text)
      end
    end

    def run
      running!
      begin
        actions.collect { |action| @success &= action.run }.all?
      ensure
        finished!
      end
    end
  end
end
