require 'githooks'

SIMPLE_MESSAGES = /(blah|foo|bar|baz|nits?)/i

def commit_message(file)
  IO.readlines(file).collect(&:strip).reject do |line|
    line =~ /\A\s*(#.*)?$/
  end.join("\n")
end

GitHooks::Hook.register 'commit-msg' do
  section 'Commit Message' do
    action 'Message Length > 5 characters' do
      on_argv do |args|
        if args.empty?
          $stderr.puts 'No commit message file passed in - are we executing in the commit-msg phase??'
          skip!
        else
          STDERR.puts "#{title}: args -> #{args.inspect}"
          STDERR.puts "#{title}: #{args.first} size -> #{commit_message(args.first).size}"
        end

        commit_message(args.first).size > 5
      end
    end

    action 'Verify no simple commit messages or words' do
      on_argv do |args|
        if args.empty?
          $stderr.puts 'No commit message file passed in - are we executing in the commit-msg phase??'
          skip!
        end

        commit_message(args.first) != SIMPLE_MESSAGES
      end
    end
  end
end
