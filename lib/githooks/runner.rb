module GitHooks
  class Runner
    include TerminalColors

    def run(argv)
      max_section_length = Hook.sections.max {|s| s.name.length }

      Hook.run_all

      Hook.sections.each do |name, section|
        hash_tail_length = (max_section_length - name.length)
        printf "===== %s %s=====\n", name, (hash_tail_length * "=")

        section.actions.each_with_index do |action, index|
          printf "\t #{index + 1}. #{action.title}"
          printf "\t    %s", action.errors.join("\n\t    ") unless action.errors.empty?
          exit 1 if section.exit_on_error and not action.errors.empty?
        end
      end

      Hook.exit
    end
  end
end
