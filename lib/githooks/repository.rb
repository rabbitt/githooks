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

require 'set'
require 'singleton'

module GitHooks
  class Repository
    extend SystemUtils

    command :git

    autoload :Config,         'githooks/repository/config'
    autoload :File,           'githooks/repository/file'
    autoload :Limiter,        'githooks/repository/limiter'
    autoload :DiffIndexEntry, 'githooks/repository/diff_index_entry'

    CHANGE_TYPE_SYMBOLS = {
      added:     'A', copied:    'C',
      deleted:   'D', modified:  'M',
      renamed:   'R', retyped:   'T',
      unknown:   'U', unmerged:  'X',
      broken:    'B', untracked: '?',
      any:       '*', tracked:   '^'
    }.freeze unless defined? CHANGE_TYPE_SYMBOLS

    CHANGE_TYPES = CHANGE_TYPE_SYMBOLS.invert.freeze unless defined? CHANGE_TYPES
    DEFAULT_DIFF_INDEX_OPTIONS = { staged: true } unless defined? DEFAULT_DIFF_INDEX_OPTIONS

    attr_reader :path, :hooks, :config

    def initialize(path = nil)
      @path   = Pathname.new(get_root_path(path || Dir.getwd))
      @hooks  = Pathname.new(@path).join('.git', 'hooks')
      @config = Repository::Config.new(self)
    end

    def hooks_script
      config['script']
    end

    def hooks_path
      config['hooks-path']
    end

    def get_root_path(path)
      git('rev-parse', '--show-toplevel', chdir: path).tap do |result|
        unless result.status.success? && result.output !~ /not a git repository/i
          fail Error::NotAGitRepo, "Unable to find a valid git repo in #{path}"
        end
      end.output.strip
    end

    def stash
      git(*%w(stash -q --keep-index -a)).status.success?
    end

    def unstash
      git(*%w(stash pop -q)).status.success?
    end

    def manifest(options = {})
      ref = options.delete(:ref)

      return staged_manifest(ref: ref) if options.delete(:staged)

      manifest_list = unstaged_manifest(ref: ref)

      tracked_manifest(ref: ref).each_with_object(manifest_list) do |file, list|
        list << file
      end if options.delete(:tracked)

      untracked_manifest(ref: ref).each_with_object(manifest_list) do |file, list|
        list << file
      end if options.delete(:untracked)

      manifest_list.sort
    end

    def staged_manifest(options = {})
      diff_index(options.merge(staged: true))
    end
    alias_method :commit_manifest, :staged_manifest

    def unstaged_manifest(options = {})
      diff_index(options.merge(staged: false))
    end

    def tracked_manifest(*)
      files = git('ls-files', '--exclude-standard').output.strip.split(/\s*\n\s*/)
      files.collect { |path|
        next unless self.path.join(path).file?
        DiffIndexEntry.from_file_path(self, path, true).to_repo_file
      }.compact
    end

    def untracked_manifest(*)
      files = git('ls-files', '--others', '--exclude-standard').output.strip.split(/\s*\n\s*/)
      files.collect { |path|
        next unless self.path.join(path).file?
        DiffIndexEntry.from_file_path(self, path).to_repo_file
      }.compact
    end

    def unpushed_commits
      result = git('log', '--format=%H', '@{upstream}..')
      if result.failure?
        if result.error =~ /no upstream configured for branch (["'])((?:(?!\1).)+)\1\z/i
          fail Error::RemoteNotSet, "No upstream remote configured for '#{$2}'"
        else
          fail Error::CommandExecutionFailure, result.error
        end
      end
      result.output.split(/\s*\n\s*/).collect(&:strip)
    end

    def revision_parent(revision)
      return unless (result = git('rev-parse', "#{revision}~1")).status.success?
      result.output.strip
    end

    def last_unpushed_commit_parent
      oldest_sha = unpushed_commits.last
      revision_parent(oldest_sha) unless oldest_sha.nil?
    end

  private

    def diff_index(options = {}) # rubocop:disable AbcSize
      options = DEFAULT_DIFF_INDEX_OPTIONS.merge(options)

      if $stdout.tty? && !options[:staged]
        cmd = %w(diff-files -C -M -B)
      else
        cmd = %w(diff-index -C -M -B)
        cmd << '--cached' if options[:staged]
        cmd << (options.delete(:ref) || 'HEAD')
      end

      Set.new(
        git(*cmd.flatten.compact).output_lines.collect { |diff_data|
          DiffIndexEntry.new(self, diff_data).to_repo_file
        }.compact
      )
    rescue StandardError => e
      puts 'Error Encountered while acquiring manifest'
      puts "Command: git #{cmd.flatten.compact.join(' ')}"
      puts "Error: #{e.class.name}: #{e.message}: #{e.backtrace[0..5].join("\n\t")}"
      exit! 1
    end

    def while_stashed(&block)
      fail ArgumentError, 'Missing required block' unless block_given?
      begin
        stash
        block.call
      ensure
        unstash
      end
    end

    def run_while_stashed(cmd)
      while_stashed { system(cmd) }
      $? == 0
    end
  end
end
