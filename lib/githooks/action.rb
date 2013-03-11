module GitHooks
  class Action
    include TerminalColors

    attr_reader :errors
    def initialize(title, &block)
      @title    = title
      @success  = true
      @status   = :prerun
      @errors   = []
      @warnings = []
      @action   = block
    end

    def title()
      if not @errors.empty?
        bright_red @title
      elsif not @warnings.empty?
        bright_yellow @title
      else
        bright_green @title
      end
    end

    def on(options = {}, &block)
      block = block || options.delete(:call)
      Repo.match_files_on(options).collect { |file|
        block.call(file[:path])
      }.all? # test that they all returned true
    end

    def run
      warnings, errors = StringIO.new, StringIO.new
      begin
        $stdout, $stderr = warnings, errors
        instance_eval(&@action)
      ensure
        @errors = errors.tap {|e| e.rewind}.read.split(/\n/)
        @warnings = warnings.tap {|w| w.rewind}.read.split(/\n/)
        $stdout, $stderr = STDOUT, STDERR
      end
    end
  end
end
