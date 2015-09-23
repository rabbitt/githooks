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

require 'set'
require 'stringio'
require_relative 'repository'

module GitHooks
  class Action
    attr_reader :title, :section, :on, :limiters
    attr_reader :success, :errors, :warnings, :benchmark
    private :section, :on
    alias_method :success?, :success

    def initialize(title, section, &block)
      fail ArgumentError, 'Missing required block' unless block_given?

      @title     = title
      @section   = section
      @on        = nil
      @limiters  = {}
      @success   = true
      @errors    = []
      @warnings  = []
      @benchmark = 0

      instance_eval(&block)

      waiting!
    end

    def manifest
      @manifest ||= section.hook.manifest.filter(section.limiters.merge(@limiters))
    end

    def colored_title
      return title.color_skipped! if skipped?
      return title.color_unknown! unless finished?
      success? ? title.color_success! : title.color_failure!
    end

    def status_symbol
      return GitHooks::SKIPPED_SYMBOL if skipped?
      return GitHooks::UNKNOWN_SYMBOL unless finished?
      success? ? GitHooks::SUCCESS_SYMBOL : GitHooks::FAILURE_SYMBOL
    end

    %w[finished running waiting skipped].each do |method|
      define_method(:"#{method}?") { @status == method.to_sym }
      define_method(:"#{method}!") { @status = method.to_sym }
    end

    def run # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      running!
      with_benchmark do
        with_captured_output {
          begin
            was_skipped = catch(:skip) do
              @success &= @on.call
              # was_skipped gets set to the return value of the block
              # which we want to be false unless `throw :skip` is called
              false
            end
            return @success
          rescue StandardError => e
            $stderr.puts "Exception thrown during action call: #{e.class.name}: #{e.message}"
            if GitHooks.debug?
              $stderr.puts "#{e.class}: #{e.message}:\n\t#{e.backtrace.join("\n\t")}"
            else
              hooks_files = e.backtrace.select! { |line| line =~ %r{/hooks/} }
              hooks_files.collect! { |line| line.split(':')[0..1].join(':') }
              $stderr.puts "  -> in hook file:line, #{hooks_files.join("\n\t")}" unless hooks_files.empty?
            end
            @success = false
          ensure
            STDERR.puts "WAS_SKIPPED? -> #{was_skipped.inspect} (#{@status.inspect})" if GitHooks.debug?
            was_skipped ? skipped! : finished!
          end
        }
      end
    end

    def with_captured_output(&_block)
      fail ArgumentError, 'expected block, none given' unless block_given?

      begin
        $stdout = warnings = StringIO.new
        $stderr = errors   = StringIO.new
        yield
      ensure
        @errors   = errors.rewind && errors.read.split(/\n/)
        @warnings = warnings.rewind && warnings.read.split(/\n/)
        $stdout   = STDOUT
        $stderr   = STDERR
      end
    end

    def with_benchmark(&_block)
      fail ArgumentError, 'expected block, none given' unless block_given?
      begin
        start_time = Time.now
        yield
      ensure
        @benchmark = Time.now - start_time
      end
    end

    def respond_to_missing?(method, include_private = false)
      section.hook.find_command(method) || super
    end

    def method_missing(method, *args, &block)
      command = section.hook.find_command(method)
      return super unless command
      run_command(command, *args, &block)
    end

    # DSL Methods

    def skip!
      throw :skip, true
    end

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

    def on_each_file
      @on = -> { manifest.collect { |file| yield file }.all? }
    end

    def on_all_files
      @on = -> { yield manifest }
    end

    def on_argv
      @on = -> { yield section.hook.args }
    end

    def on(*args)
      @on = -> { yield(*args) }
    end

  private

    def run_command(command, *args, &block)
      prefix = nil
      args.extract_options.tap { |options|
        prefix = options.delete(:prefix_output)
      }

      result = command.execute(*args, &block)
      result.output_lines(prefix).each { |line| $stdout.puts line }
      result.error_lines(prefix).each { |line| $stderr.puts line }
      result.status.success?
    end
  end
end
