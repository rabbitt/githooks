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
    extend self

    MARK_SUCCESS = '✓'
    MARK_FAILURE = 'X'
    MARK_UNKNOWN = '?'

    def start
      max_section_length = Hook.sections.max {|s| s.name.length }

      success = Hook.run

      sections = Hook.sections.select {|section| not section.actions.empty? }

      sections.each do |section|
        hash_tail_length = (max_section_length - section.name.length)
        printf "===== %s %s=====\n", section.colored_name, ("=" * hash_tail_length)

        section.actions.each_with_index do |action, index|
          printf "  %d. [ %s ] %s\n", (index + 1), action.state_symbol, action.colored_title

          action.errors.each do |error|
            printf "    %s %s\n", bright_red(MARK_FAILURE), error
          end unless action.errors.empty?

          state_string = ( action.success? ? bright_green(MARK_SUCCESS) : bright_yellow(MARK_UNKNOWN) )
          action.warnings.each do |warning|
            printf "    %s %s\n", state_string, warning
          end unless action.warnings.empty?
        end
        puts
      end

      success = 1 if ENV['FORCE_ERROR']

      if not success
        $stderr.puts "Commit failed due to errors listed above. Please fix and attempt your commit again."
      end

      exit(success ? 0 : 1)
    end
  end
end
