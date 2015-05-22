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
    attr_reader :name, :hook, :success, :actions, :benchmark, :limiters

    alias_method :title, :name
    alias_method :success?, :success

    class << self
      def key_from_name(name)
        name.to_s.downcase.gsub(/[\W\s]+/, '_').to_sym
      end
    end

    def initialize(name, hook, &block)
      @name      = name.to_s.titleize
      @success   = true
      @actions   = []
      @limiters  = hook.limiters
      @hook      = hook
      @benchmark = 0

      instance_eval(&block)

      waiting!
    end

    # overrides previous action method to only return
    # actions that have a non-empty manifest
    def actions
      @actions.reject { |action| action.manifest.empty? }
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
      @actions.all?(&:finished?)
    end

    def wait_count
      @actions.select(&:waiting?).size
    end

    def name(phase = GitHooks::HOOK_NAME)
      "#{(phase || GitHooks::HOOK_NAME).to_s.camelize} :: #{@name}"
    end

    def colored_name(phase = GitHooks::HOOK_NAME)
      status_colorize name(phase)
    end

    def key_name
      self.class.key_from_name(@name)
    end

    def status_colorize(text)
      return text.unknown! unless finished? && completed?
      success? ? text.success! : text.failure!
    end

    def run
      running!
      begin
        time_start = Time.now
        actions.collect { |action| @success &= action.run }.all?
      ensure
        @benchmark = Time.now - time_start
        finished!
      end
    end

    ## DSL

    def config_path
      GitHooks.hooks_root.join('configs')
    end

    def config_file(*path_components)
      config_path.join(*path_components)
    end

    def lib_path
      GitHooks.hooks_root.join('lib')
    end

    def lib_file(*path_components)
      lib_path.join(*path_components)
    end

    def limit(type)
      unless @limiters.include? type
        @limiters[type] ||= Repository::Limiter.new(type)
      end
      @limiters[type]
    end

    def action(title, &block)
      fail ArgumentError, 'expected block, received none' unless block_given?
      @actions << Action.new(title, self, &block)
      self
    end
  end
end
