# encoding: utf-8
require 'stringio'
require 'open3'

module GitHooker
  class Action
    include TerminalColors

    attr_reader :errors, :warnings, :title, :success

    def initialize(title, &block)
      raise ArgumentError, "Missing required block for Action#new" unless block_given?

      @title    = title.to_s.titleize
      @success  = true
      @errors   = []
      @warnings = []
      @action   = DSL.new(block)

      waiting!
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

    class DSL
      include Repo

      def initialize(block)
        @block = block
      end

      def call() instance_eval(&@block); end

      # DSL Methods
      def args() ARGV.dup; end

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
    end
  end
end
