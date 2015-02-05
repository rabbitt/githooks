# encoding: utf-8
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
require 'githooks/error'
require 'githooks/core_ext'
require 'githooks/core_ext/colorize'
require 'githooks/version'

module GitHooks
  AUTHOR = 'Carl P. Corliss <rabbitt@gmail.com>'

  autoload :Config,         'githooks/config'
  autoload :CommandRunner,  'githooks/command'
  autoload :Command,        'githooks/command'
  autoload :CLI,            'githooks/cli'
  autoload :Hook,           'githooks/hook'
  autoload :Section,        'githooks/section'
  autoload :Action,         'githooks/action'
  autoload :Repository,     'githooks/repository'
  autoload :Runner,         'githooks/runner'
  autoload :SystemUtils,    'githooks/system_utils'

  class << self
    attr_reader :debug, :verbose, :ignore_script

    def debug?
      return true if ENV['GITHOOKS_DEBUG']
      return true if ARGV.include?('--debug')
      return true if ARGV.include?('-d')
      debug
    end

    def debug=(value)
      @debug = !!value
    end

    def verbose?
      return true if ENV['GITHOOKS_VERBOSE']
      return true if ARGV.include?('--verbose')
      return true if ARGV.include?('-v')
      verbose
    end

    def verbose=(value)
      @verbose = !!value
    end

    def ignore_script=(value)
      @ignore_script = !!value
    end

    def hook_name
      case GitHooks::HOOK_NAME.to_s
        when 'githooks', 'irb', '', nil then 'pre-commit'
        else GitHooks::HOOK_NAME
      end
    end
  end

  SUCCESS_SYMBOL = '✓'.success! unless defined? SUCCESS_SYMBOL
  FAILURE_SYMBOL = 'X'.failure! unless defined? FAILURE_SYMBOL
  UNKNOWN_SYMBOL = '?'.unknown! unless defined? UNKNOWN_SYMBOL

  LIB_PATH = Pathname.new(__FILE__).dirname.realpath unless defined? LIB_PATH
  GEM_PATH = LIB_PATH.parent                         unless defined? GEM_PATH
  BIN_PATH = GEM_PATH.join('bin')                    unless defined? BIN_PATH

  SCRIPT_PATH = Pathname.new($0)          unless defined? SCRIPT_PATH
  SCRIPT_NAME = SCRIPT_PATH.basename.to_s unless defined? SCRIPT_NAME
  HOOK_NAME   = SCRIPT_NAME.to_s          unless defined? HOOK_NAME

  if ARGV.include? '--ignore-script'
    ARGV.delete('--ignore-script')
    self.ignore_script = true
  end
end
