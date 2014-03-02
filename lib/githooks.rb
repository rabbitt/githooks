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
require 'githooks/core_ext'
require 'githooks/version'
require 'pry'

module GitHooks
  autoload :Hook,              'githooks/hook'
  autoload :Section,           'githooks/section'
  autoload :Action,            'githooks/action'
  autoload :Repository,        'githooks/repository'
  autoload :Runner,            'githooks/runner'
  autoload :Error,             'githooks/error'
  autoload :SystemUtils,       'githooks/system_utils'
  autoload :TerminalColors,    'githooks/terminal_colors'

  LIB_PATH = Pathname.new(__FILE__).dirname
  GEM_PATH = LIB_PATH.parent

  SCRIPT_PATH     = Pathname.new($0).realpath
  SCRIPT_NAME     = SCRIPT_PATH.basename.to_s
  SCRIPT_DIR      = SCRIPT_PATH.dirname

  REPO_ROOT   = (path = Repository.root_path).empty? ? SCRIPT_DIR : Pathname.new(path)

  HOOK_NAME   = SCRIPT_NAME.to_s.underscore.to_sym

  VALID_PHASES = %w{ any pre-commit commit-msg }.collect(&:to_sym).freeze
end
