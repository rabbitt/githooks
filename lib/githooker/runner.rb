module GitHooker
  module Runner
    extend TerminalColors
    extend self

    def start
      max_section_length = Hook.sections.max {|s| s.name.length }

      success = Hook.run

      Hook.sections.select {|section|
        not section.actions.empty?
      }.each do |section|
        hash_tail_length = (max_section_length - section.name.length)
        printf "===== %s %s=====\n", section.colored_name, ("=" * hash_tail_length)

        shown_incomplete = false
        section.actions.each_with_index do |action, index|
          if not section.completed? and action.waiting? and not shown_incomplete
            shown_incomplete = true
            puts bright_yellow("  -- this section incomplete due 'stop_on_error' setting and previous errors --  ")
          end

          printf "  %d. [ %s ] %s\n", (index + 1), action.state_symbol, action.colored_title

          action.errors.each do |error|
            printf "    %s %s\n", bright_red(MARK_FAILURE), error
          end unless action.errors.empty?

          action.warnings.each do |warning|
            printf "    %s %s\n", ( action.success? ? bright_green(MARK_SUCCESS) : bright_yellow(MARK_UNKNOWN) ), warning
          end unless action.warnings.empty?
        end
        puts
      end

      success = 1 if ENV['FORCE_ERROR']

      if not success
        $stderr.puts "Commit failed due to errors listed above. Please fix and attempt your commit again."
      end

      exit(success ? 0 : 1)
    end
  end
end
