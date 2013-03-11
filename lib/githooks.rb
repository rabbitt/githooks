#!/usr/bin/env ruby

require 'pathname'
require 'githooks/core_ext'

module GitHooks
  autoload :Hook,    'githooks/hook'
  autoload :Repo,    'githooks/repo'
  autoload :Runner,  'githooks/runner'
  autoload :Section, 'githooks/section'
  autoload :Action,  'githooks/action'
  autoload :VERSION, 'githooks/version'

  LIB_PATH = Pathname.new(__FILE__).dirname
  GEM_PATH = LIB_PATH.parent

  SCRIPT_NAME = Pathname.new($0).basename
  SCRIPT_DIR  = Pathname.new($0).dirname.realdirpath
  SCRIPT_PATH = SCRIPT_DIR + SCRIPT_NAME

  VERSION = IO.read(GEM_PATH + 'VERSION')

end

# # --- commit_hooks.rb
# require 'githooks'

# GitHooks::Hook.register(:pre_commit) do
#   section :generic
#
#   perform "Valid Puppet Syntax" do
#     on :name => /\.pp$/, :call => Puppet.method(:parser_test)
#   end
#
#   section :policy
#
#   perform "No Leading Tabs" do
#     on :type => [:added, :modified] { |file_path|
#       IO.read(file_path).split(/\n/).tap { |contents|
#         contents.each_with_index do |line, index|
#           if line.match(/^[ ]*\t/)
#             printf "%#{contents.length.to_s.size}d: %s\n", index, line
#           end
#         end
#       }.none? { |line| line.match(/^[ ]*\t/) }
#     }
#   end
#
#   perform "Leading Spaces Multiple of 2" do
#     on :type => [:added, :modified] { |file_path|
#       IO.read(file_path).split(/\n/).tap { |contents|
#         contents.each_with_index do |line, index|
#           if line.scan(/^[ ]+/).first.to_s.size % 2 > 0
#             printf "%#{contents.length.to_s.size}d: %s\n", index, line
#           end
#         end
#       }.none? { |line| line.scan(/^[ ]+/).first.to_s.size % 2 > 0 }
#     }
#   end
#



