module GitHooks
  class Runner
    def run(argv)
      success = true
      max_section_length = Hook.sections.max {|s| s.name.length }

      Hook.sections.each do |name, section|
        hash_tail_length = (max_section_length - name.length)
        printf "===== %s %s=====\n", name, (hash_tail_length * "=")

        section.actions.each_with_index do |action, index|

          printf "\t #{index + 1}. #{}"
      check_files = Hash[changed_files.select{ |file,changetypes|
        file =~ check[:match][:names] && (changetypes - check[:match][:changes]).empty?
      }].keys.sort

      max_length = check_files.inject(0) { |size,filename| size = filename.size > size ? filename.size : size }

      check_files.each do |file|
        printf "   ---- %-#{max_length}s\t", file
        results = %x{ #{check[:command]} "#{file}" }
        successful &= $?.success?
        puts($?.success? ? STATUS_PASSED : STATUS_FAILED)
        puts results unless results =~ /^\s*$/
      end

      puts

      exit( STATUS_PASSED : STATUS_FAILED)
    end
  end
end

(19) == 19
(19) - (16) == 3
===== abcdefghijklmnop ======== 7 1 16 1 7
===== abcdefghijklmnopqrs ===== 5 1 19 1 5