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

require 'githooks/terminal_colors'

module GitHooks
  module Runner
    extend TerminalColors

    MARK_SUCCESS = '✓'
    MARK_FAILURE = 'X'
    MARK_UNKNOWN = '?'

    def start(phase = 'pre-commit', repo_path = nil) # rubocop:disable MethodLength
      success        = Hook.phases[phase.to_sym].repository_path(repo_path).run
      section_length = Hook.sections.max { |s| s.title.length }
      sections       = Hook.sections.select { |section| !section.actions.empty? }

      sections.each do |section|
        hash_tail_length = (section_length - section.title.length)
        printf "===== %s %s=====\n", section.colored_name(phase), ('=' * hash_tail_length)

        section.actions.each_with_index do |action, index|
          printf "  %d. [ %s ] %s\n", (index + 1), action.state_symbol, action.colored_title

          action.errors.each do |error|
            printf "    %s %s\n", color_bright_red(MARK_FAILURE), error
          end

          state_string = ( action.success? ? color_bright_green(MARK_SUCCESS) : color_bright_yellow(MARK_UNKNOWN))
          action.warnings.each do |warning|
            printf "    %s %s\n", state_string, warning
          end
        end
        puts
      end

      success = 1 if ENV['FORCE_ERROR']

      unless success
        $stderr.puts 'Commit failed due to errors listed above.'
        $stderr.puts 'Please fix and attempt your commit again.'
      end

      exit(success ? 0 : 1)
    end
    module_function :start

    def load_tests(path) # rubocop:disable MethodLength
      hooks_root = Pathname.new(path).realpath
      hooks_libs = hooks_root + 'lib'
      gemfile    = hooks_root + 'Gemfile'
      ENV['BUNDLE_GEMFILE'] = (hooks_root + 'Gemfile').to_s

      puts "loading Gemfile from: #{gemfile}"

      if gemfile.exist?
        begin
          require 'bundler'
          Bundler.require(:default)
        rescue LoadError
          puts "Unable to load bundler - please make sure it's installed."
          raise # rubocop:disable SignalException
        rescue Bundler::GemNotFound
          puts 'Error: #{e.message}'
          puts 'Did you bundle install your Gemfile?'
          raise # rubocop:disable SignalException
        end
      end

      $:.unshift hooks_libs.to_s
      libs = SystemUtils.with_path(hooks_libs) { Dir['**/*.rb'] }
      libs.each { |lib| require lib.gsub('.rb', '') }
    end
    module_function :load_tests
  end
end
