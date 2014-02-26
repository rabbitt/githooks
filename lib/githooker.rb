#!/usr/bin/env ruby

require 'pathname'
require 'githooker/core_ext'


module GitHooker
  autoload :Hook,              'githooker/hook'
  autoload :Repo,              'githooker/repo'
  autoload :Runner,            'githooker/runner'
  autoload :Section,           'githooker/section'
  autoload :Action,            'githooker/action'
  autoload :TerminalColors,    'githooker/terminal_colors'
  autoload :NotAGitRepoError,  'githooker/repo'
  autoload :RegistrationError, 'githooker/hook'

  LIB_PATH = Pathname.new(__FILE__).dirname
  GEM_PATH = LIB_PATH.parent

  SCRIPT_NAME     = Pathname.new($0).basename.to_s
  SCRIPT_DIR      = Pathname.new($0).dirname.realpath
  SCRIPT_PATH     = SCRIPT_DIR + SCRIPT_NAME

  REPO_ROOT   = (path = Repo::root_path).empty? ? SCRIPT_DIR : Pathname.new(path)

  HOOK_NAME   = SCRIPT_NAME.to_s.underscore.to_sym

  VERSION = IO.read(GEM_PATH + 'VERSION')

  VALID_PHASES = %w{ any pre-commit post-commit commit-msg }.collect(&:to_sym).freeze
end

# # # --- commit_hooks.rb
# #!/usr/bin/env ruby
# require 'githooker'

# GitHooker::Hook.register(:pre_commit) do

#   section :generic
#   exit_on_error true

#   perform "Valid Puppet Syntax" do
#     on :name => /\.pp$/, :call => Puppet.method(:parser_test)
#   end

#   perform "Validate Zone File" do
#     on :name => /\.db$/ do |file|
#       system("named-checkzone #{file}") == 0
#     end
#   end

#   section :policy

#   perform "No Leading Tabs" do
#     on :change => [:added, :modified] { |file_path|
#       IO.read(file_path).split(/\n/).tap { |contents|
#         contents.each_with_index do |line, index|
#           if line.match(/^[ ]*\t/)
#             $stderr.printf "%#{contents.length.to_s.size}d: %s\n", index, line
#           end
#         end
#       }.none? { |line| line.match(/^[ ]*\t/) }
#     }
#   end

#   perform "Leading Spaces Multiple of 2" do
#     on :change => [:added, :modified] { |file_path|
#       IO.read(file_path).split(/\n/).tap { |contents|
#         contents.each_with_index do |line, index|
#           if line.scan(/^[ ]+/).first.to_s.size % 2 > 0
#             $stderr.printf "%#{contents.length.to_s.size}d: %s\n", index, line
#           end
#         end
#       }.none? { |line| line.scan(/^[ ]+/).first.to_s.size % 2 > 0 }
#     }
#   end




