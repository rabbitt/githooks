# encoding: utf-8
require 'stringio'
require 'open3'

module GitHooker
  class Action
    include TerminalColors
    include Repo

    attr_reader :errors, :warnings, :title, :success

    def initialize(title, &block)
      raise ArgumentError, "Missing required block for Action#new" unless block_given?

      @title    = title.to_s.titleize
      @success  = true
      @errors   = []
      @warnings = []
      @action   = block
    end

    def success?() @success; end

    def title()
      success_colored @title
    end

    def state_symbol
      symbol = success? ? "✓" : 'X'
      success_colored symbol
    end

    def success_colored(text)
      success? ? bright_green(text) : bright_red(text)
    end

    def on(options = {}, &block)
      block = block || options.delete(:call)
      Repo.match_files_on(options).collect { |file|
        block.call(file)
      }.all? # test that they all returned true
    end

    def execute(cmd, output_line_prefix=nil)
      Open3.popen3(cmd) { |i, o, e, t|

        o.read.split(/\n/).each do |line|
          $stdout.puts output_line_prefix ? "#{output_line_prefix}: #{line}" : line
        end

        e.read.split(/\n/).each do |line|
          $stderr.puts output_line_prefix ? "#{output_line_prefix}: #{line}" : line
        end

        t.value
      }.success?
    end

    def run
      warnings, errors = StringIO.new, StringIO.new
      begin
        $stdout, $stderr = warnings, errors
        @success &= instance_eval(&@action)
        return @success
      ensure
        @errors = errors.tap {|e| e.rewind}.read.split(/\n(?:[\t ]*)/)
        @warnings = warnings.tap {|w| w.rewind}.read.split(/\n(?:[\t ]*)/)
        $stdout, $stderr = STDOUT, STDERR
      end
    end
  end
end
