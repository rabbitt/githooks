require 'githooks'

RUBY_FILE_REGEXP = %r:
  ^(
    Rakefile |
    .+\.gemspec |
    lib/.+\.(task|rb) |
    bin/.+ |
    .hooks/.+?\.rb
  )$
:xi.freeze

GitHooks::Hook.register 'pre-commit' do
  commands :ruby, :rubocop
  limit(:type).to :modified, :added, :untracked, :tracked
  limit(:path).to RUBY_FILE_REGEXP

  section 'Standards' do
    action 'Validate Ruby Syntax' do
      on_each_file do |file|
        ruby '-c', file.path, prefix_output: file.path
      end
    end

    action 'Validate Ruby Standards' do
      on_all_files do |files|
        args = %W{
          -c #{config_file('rubocop.yml')} -D --format clang
        }.concat(files.collect(&:path))

        rubocop(*args, strip_empty_lines: true)
      end
    end

    action 'No Leading Tabs in Ruby files' do
      on_each_file do |file|
        file.grep(/^[ ]*(\t+)/).tap do |matches|
          matches.each do |line_number, line_text|
            line_text.gsub!(/^[ ]*(\t+)/) do
              underscores = '_' * $1.size
              bright_red(underscores)
            end
            $stderr.printf "%s:%#{matches.last.first.to_s.size}d: %s\n", file.path, line_number, line_text
          end
        end.empty?
      end
    end
  end
end
