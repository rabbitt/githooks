=begin
Copyright (C) 2013 Carl P. Corliss

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
=end

require 'pathname'
require 'githooks/core_ext'
require 'githooks/version'
require 'pry'

module GitHooks
  autoload :Hook,              'githooks/hook'
  autoload :Repository,        'githooks/repository'
  autoload :Runner,            'githooks/runner'
  autoload :Section,           'githooks/section'
  autoload :Action,            'githooks/action'
  autoload :TerminalColors,    'githooks/terminal_colors'
  autoload :NotAGitRepoError,  'githooks/repo'
  autoload :RegistrationError, 'githooks/hook'

  LIB_PATH = Pathname.new(__FILE__).dirname
  GEM_PATH = LIB_PATH.parent

  SCRIPT_NAME     = Pathname.new($0).basename.to_s
  SCRIPT_DIR      = Pathname.new($0).dirname.realpath
  SCRIPT_PATH     = SCRIPT_DIR + SCRIPT_NAME

  REPO_ROOT   = (path = Repository::root_path).empty? ? SCRIPT_DIR : Pathname.new(path)

  HOOK_NAME   = SCRIPT_NAME.to_s.underscore.to_sym

  VALID_PHASES = %w{ any pre-commit post-commit commit-msg }.collect(&:to_sym).freeze
end

=begin

require 'githooker'

SIMPLE_MESSAGES = /^\s*(blah|\.+|foo|bar|baz|nits?|)\s*$/

hook 'commit-msg' do
  section "Commit Log" do
    test "Message Length > 5 characters" do
      IO.read(args.first).size > 5 unless args.empty?
    end

    test "Verify no simple commit messages" do
      IO.read(args.first) !~ SIMPLE_MESSAGES unless args.empty?
    end
  end
end

hook 'pre-commit' do
  commands :'scss-lint', :ruby

  RUBY_FILE_REGEXP = %r{^(app|lib)/.+\.rb$}.freeze

  section 'Standard' do

    test 'Validate Ruby Syntax' do
      limit(:type).to :modification, :addition
      limit(:path).to RUBY_FILE_REGEXP

      on_each_file do |file|
        ruby '-c', file.path
      end
    end

    test "No Leading Spaces" do
      limit(:type).to :modification, :addition
      limit(:path).to RUBY_FILE_REGEXP

      on_each_file do |file|
        file.grep(/^[ ]+/).tap { |matches|
          matches.each do |line_number, line_text|
            $stderr.printf "%#{contents.length.to_s.size}d: %s\n", line_number, line_text
          end
        }.empty?
      end
    end

    test 'Validate CSS Syntax' do
      limit(:type).to :modification, :addition
      limit(:path).to %r{^(app|lib)/.+css$}

      on_all_files do |files|
        scss_lint files.collect(&:path)
      end
    end

  end
end

=end
