module GitHooks
  class Hook
    class Base
      attr_reader :title, :command, :show_name

      def match_on(type, options)
        case type
          when :and, :or, 'and', 'or' then
            @match = [type.to_sym] + options.collect
          else
            @match = [type, options]
        end
      end

      def match(check_files)
        case (type = @match.shift)
          when :and then check_files.select { |f| @match.all? {|match| match_file(f, *match) } }
          when :or then check_files.select { |f| @match.any? {|match| match_file(f, *match) } }
          else check_files.select{|f| match_file(f, type, @match.first) }
        end
      end

      def match_files_with()
      def match_file(file, matchtype, matchvalue)
        case matchtype
          when :name then
            case matchvalue
              when Regexp then file[:fqpn] =~ matchvalue
            end
        end
      end

      def run(argv)
        puts @title

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
      end
    end
  end
end