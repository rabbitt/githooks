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
require 'githooks/version'

module GitHooks
  AUTHOR = 'Carl P. Corliss <rabbitt@gmail.com>'

  autoload :Config,            'githooks/config'
  autoload :CommandRunner,     'githooks/command'
  autoload :Command,           'githooks/command'
  autoload :CLI,               'githooks/cli'
  autoload :Hook,              'githooks/hook'
  autoload :Section,           'githooks/section'
  autoload :Action,            'githooks/action'
  autoload :Repository,        'githooks/repository'
  autoload :Runner,            'githooks/runner'
  autoload :SystemUtils,       'githooks/system_utils'
  autoload :TerminalColors,    'githooks/terminal_colors'

  class << self
    attr_reader :debug, :verbose, :ignore_script

    def debug?
      !!ENV['GITHOOKS_DEBUG'] || ARGV.include?('--debug') || debug
    end

    def debug=(value)
      @debug = !!value
    end

    def verbose?
      !!ENV['GITHOOKS_VERBOSE'] || ARGV.include?('--verbose') || verbose
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

  LIB_PATH = Pathname.new(__FILE__).dirname.realpath
  GEM_PATH = LIB_PATH.parent
  BIN_PATH = GEM_PATH + 'bin'

  SCRIPT_PATH = Pathname.new($0)
  SCRIPT_NAME = SCRIPT_PATH.basename.to_s
  HOOK_NAME   = SCRIPT_NAME.to_s

  if ARGV.include? '--ignore-script'
    ARGV.delete('--ignore-script')
    self.ignore_script = true
  end
end
