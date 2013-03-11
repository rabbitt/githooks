module GitHooks
  module Runner
    extend TerminalColors
    extend self

    def start
      max_section_length = Hook.sections.max {|s| s.name.length }

      success = Hook.run

      Hook.sections.each do |section|
        hash_tail_length = (max_section_length - section.name.length)
        printf "===== %s %s=====\n", section.name, ("=" * hash_tail_length)

        section.each_with_index do |action, index|
          printf "  %d. [ %s ] %s\n", (index + 1), action.state_symbol, action.title

          action.errors.each do |error|
            printf "    %s %s\n", bright_red('-->'), error
          end unless action.errors.empty?

          action.warnings.each do |warning|
            printf "    %s %s\n", ( action.success? ? bright_green('-->') : bright_yellow('-->') ), warning
          end unless action.warnings.empty?

          exit 1 if section.exit_on_error and not action.errors.empty?
        end

        puts
      end

      success = 1 if ENV['FORCE_ERROR']
      exit(success ? 0 : 1)
    end
  end
end
