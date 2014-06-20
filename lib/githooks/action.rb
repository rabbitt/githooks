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

require 'stringio'
require 'open3'
require 'set'

module GitHooks
  class Action # rubocop:disable Style/ClassLength
    include TerminalColors

    attr_reader :title, :section, :on, :limiters
    attr_reader :success, :errors, :warnings, :benchmark
    private :section, :on
    alias_method :success?, :success

    def initialize(title, section, &block)
      fail ArgumentError, 'Missing required block' unless block_given?

      @title     = title
      @section   = section
      @on        = nil
      @limiters  = Set.new
      @success   = true
      @errors    = []
      @warnings  = []
      @benchmark = 0

      instance_eval(&block)

      waiting!
    end

    def manifest
      @manifest ||= section.hook.manifest.filter(@limiters)
    end

    def colored_title
      status_colorize title
    end

    def state_symbol
      return status_colorize('?') unless finished?
      status_colorize success? ? '✓' : 'X'
    end

    %w(finished running waiting).each do |method|
      define_method(:"#{method}?") { @status == method.to_sym }
      define_method(:"#{method}!") { @status = method.to_sym }
    end

    def status_colorize(text)
      return color_dark_cyan(text) unless finished?
      success? ? color_bright_green(text) : color_bright_red(text)
    end

    def run # rubocop:disable MethodLength
      warnings, errors = StringIO.new, StringIO.new

      begin
        running!
        $stdout, $stderr = warnings, errors
        time_start = Time.now
        @success &= @on.call
      rescue => error
        errors.puts "Exception thrown during action call: #{error.class.name}: #{error.message}"

        if !GitHooks.debug?
          hooks_files = error.backtrace.select! { |line| line =~ %r{/hooks/} }
          hooks_files.collect! { |line| line.split(':')[0..1].join(':') }
          errors.puts "  -> in hook file:line, #{hooks_files.join("\n\t")}" unless hooks_files.empty?
        else
          errors.puts "\t#{error.backtrace.join("\n\t")}"
        end

        @success = false
      ensure
        @benchmark = Time.now - time_start
        @errors, @warnings = [errors, warnings].collect do |io|
          io.rewind
          io.read.split(/\n/)
        end

        $stdout, $stderr = STDOUT, STDERR
        finished!
      end

      @success
    end

    def method_missing(method, *args, &block)
      command = section.hook.find_command(method)
      return super unless command
      run_command(command, *args, &block)
    end

    # DSL Methods

    def limit(type)
      (find_limiter(type) || Repository::Limiter.new(type)).tap do |limiter|
        @limiters << limiter
      end
    end

    def on_each_file(&block)
      @on = -> { manifest.collect { |file| block.call(file) }.all? }
    end

    def on_all_files(&block)
      @on = ->() { block.call manifest }
    end

    def on_argv(&block)
      @on = ->() { block.call section.hook.args }
    end

    def on(*args, &block)
      @on = ->() { block.call(*args) }
    end

  private

    def find_limiter(type)
      @limiters.select { |l| l.type == type }.first
    end

    def run_command(command, *args, &block)
      options = args.extract_options
      prefix  = options.delete(:prefix_output)
      args << options

      command.execute(*args, &block).tap do |res|
        res.output.split(/\n/).each do |line|
          $stdout.puts prefix ? "#{prefix}: #{line}" : line
        end

        res.error.split(/\n/).each do |line|
          $stderr.puts prefix ? "#{prefix}: #{line}" : line
        end
      end.status.success?
    end
  end
end
