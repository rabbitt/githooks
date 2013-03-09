#!/usr/bin/env ruby

require 'pathname'
require 'core_ext'

module GitHooks
  autoload :VERSION, 'githooks/version'

  CHANGE_FILTERS = {
    :added    => 'A', :copied   => 'C', :deleted  => 'D', :modified => 'M',
    :renamed  => 'R', :retyped  => 'T', :unknown  => 'U', :unmerged => 'X',
    :broken   => 'B', :any      => '*'
  }

  SCRIPT_NAME     = Pathname.new($0).basename
  SCRIPT_DIR      = Pathname.new($0).dirname.realdirpath
  SCRIPT_PATH     = SCRIPT_DIR + SCRIPT_NAME
end

# require 'githooks'
# GitHooks.run_hooks # runs all hooks in sorted order from .git/hooks/hook_name directory

# # --- 01_test_parser_syntax.rb
# require 'githooks'
# GitHooks::Hook.register(:pre_commit) |hook|
#   section :syntax
#   title "Syntax Check"
#   action = Puppet.method(:parser_test)
#   match_files_with /\.pp$/
# end

# # --- 02_test_tabs_vs_spaces.rb




