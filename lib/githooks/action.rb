# encoding: utf-8
require 'stringio'

module GitHooks
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

    def title()
      if not @errors.empty? or not @success
        bright_red @title
      elsif not @warnings.empty?
        bright_yellow @title
      else
        bright_green @title
      end
    end

    def state_symbol
      if not @errors.empty? or not @success
        bright_red "X"
      elsif not @warnings.empty?
        bright_yellow "✓"
      else
        bright_green "✓"
      end
    end

    def on(options = {}, &block)
      block = block || options.delete(:call)
      Repo.match_files_on(options).collect { |file|
        block.call(file)
      }.all? # test that they all returned true
    end

    def run
      warnings, errors = StringIO.new, StringIO.new
      begin
        $stdout, $stderr = warnings, errors
        @success &= instance_eval(&@action)
        return @success
      ensure
        @errors = errors.tap {|e| e.rewind}.read.split(/\n/)
        @warnings = warnings.tap {|w| w.rewind}.read.split(/\n/)
        $stdout, $stderr = STDOUT, STDERR
      end
    end
  end
end
