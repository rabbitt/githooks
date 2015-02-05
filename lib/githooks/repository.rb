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

module GitHooks
  class Repository # rubocop:disable ClassLength
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

    @__instance__ = {}
    @__mutex__    = Mutex.new

    def self.instance(path = Dir.getwd)
      path = Pathname.new(path).realpath
      strpath = path.to_s
      return @__instance__[strpath] if @__instance__[strpath]

      @__mutex__.synchronize do
        return @__instance__[strpath] if @__instance__[strpath]
        @__instance__[strpath] = new(path)
      end
    end

    def self.method_missing(method, *args, &block)
      return super unless instance.public_methods.include? method
      instance.public_send(method, *args, &block)
    end

    attr_reader :root_path

    def initialize(path = Dir.getwd)
      @root_path = get_root_path(path)
    end
    protected :initialize

    def config
      @config ||= Repository::Config.new(root_path)
    end

    def get_root_path(path)
      git('rev-parse', '--show-toplevel', chdir: path).tap do |result|
        unless result.status.success? && result.output !~ /not a git repository/i
          fail Error::NotAGitRepo, "Unable to find a valid git repo in #{path}"
        end
      end.output.strip
    end

    def stash
      git(*%w( stash -q --keep-index -a)).status.success?
    end

    def unstash
      git(*%w(stash pop -q)).status.success?
    end

    def manifest(options = {}) # rubocop:disable AbcSize
      ref = options.delete(:ref)
      return staged_manifest(ref: ref) if options.delete(:staged)

      manifest_list = unstaged_manifest(ref: ref)

      if options.delete(:tracked)
        tracked_manifest(ref: ref).each_with_object(manifest_list) do |file, list|
          list << file unless list.include?(file)
        end
      end

      if options.delete(:untracked)
        untracked_manifest(ref: ref).each_with_object(manifest_list) do |file, list|
          list << file unless list.include?(file)
        end
      end

      manifest_list.sort!
      manifest_list.uniq { |f| f.path.to_s }
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
      files.collect { |path| DiffIndexEntry.from_file_path(path, true).to_repo_file }
    end

    def untracked_manifest(*)
      files = git('ls-files', '--others', '--exclude-standard').output.strip.split(/\s*\n\s*/)
      files.collect { |path| DiffIndexEntry.from_file_path(path).to_repo_file }
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

      git(*cmd.compact.compact).output_lines.collect do |diff_data|
        DiffIndexEntry.new(diff_data).to_repo_file
      end
    rescue
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
