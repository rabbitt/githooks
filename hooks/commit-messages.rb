require 'githooks'

SIMPLE_MESSAGES = /^\s*(blah|\.+|foo|bar|baz|nits?|)\s*$/

GitHooks::Hook.register 'commit-msg' do
  section "Commit Message" do
    action "Message Length > 5 characters" do
      on_argv do |args| 
        if args.empty?
          $stderr.puts "No commit message file passed in - are we executing in the commit-msg phase??"
          return false
        end

        IO.read(args.first).size > 5 unless args.empty?
      end
    end

    action "Verify no simple commit messages" do
      on_argv do |args|
        if args.empty?
          $stderr.puts "No commit message file passed in - are we executing in the commit-msg phase??"
          return false
        end
        # make sure there is at least one line that isn't a simple message
        IO.read(args.first).split(/\n/).any? { |line| line !~ SIMPLE_MESSAGES }
      end
    end
  end
end

