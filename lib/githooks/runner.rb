module GitHooks
  module Runner
    extend TerminalColors
    extend self

    def start
      max_section_length = Hook.sections.max {|s| s.name.length }

      success = Hook.run_for(HOOK_NAME)

      Hook.sections.each do |section|
        hash_tail_length = (max_section_length - section.name.length)
        printf "===== %s %s=====\n", section.name, ("=" * hash_tail_length)

        section.each_with_index do |action, index|
          printf "  #{index + 1}. #{action.title}\n"
          printf "    %s %s\n", bright_red('-->'), action.errors.join("\n\t    ")unless action.errors.empty?
          printf "    %s %s\n", bright_yellow('-->'), action.warnings.join("\n\t    ") unless action.warnings.empty?
          exit 1 if section.exit_on_error and not action.errors.empty?
        end

        puts
      end

      success = 1 if ENV['FORCE_ERROR']
      exit(success ? 0 : 1)
    end
  end
end
