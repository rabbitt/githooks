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

require 'ostruct'
require 'singleton'
require 'open3'

module GitHooks
  class Repository
    autoload :Config,  'githooks/repository/config'
    autoload :File,    'githooks/repository/file'
    autoload :Limiter, 'githooks/repository/limiter'

    CHANGE_TYPE_SYMBOLS = {
      added:    'A', copied:   'C',
      deleted:  'D', modified: 'M',
      renamed:  'R', retyped:  'T',
      unknown:  'U', unmerged: 'X',
      broken:   'B', any:      '*'
    }.freeze

    CHANGE_TYPES = CHANGE_TYPE_SYMBOLS.invert.freeze

    DEFAULT_DIFF_INDEX_OPTIONS = { staged: true, ref: 'HEAD' }

    @__instance__ = {}
    @__mutex__    = Mutex.new
    def self.instance(path = Dir.getwd)
      path = Pathname.new(path).realpath
      return @__instance__[path] if @__instance__[path]

      @__mutex__.synchronize do
        return @__instance__[path] if @__instance__[path]
        @__instance__[path] = new(path)
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

    def command(*args)
      git.execute(*args.flatten)
    end

    def get_root_path(path)
      command('rev-parse', '--show-toplevel', path: path).tap do |result|
        unless result.status.success? && result.output !~ /not a git repository/i
          fail Error::NotAGitRepo, "Unable to find a valid git repo in #{path}"
        end
      end.output.strip
    end

    def stash
      command(%w( stash -q --keep-index -a)).status.success?
    end

    def unstash
      command(%w(stash pop -q)).status.success?
    end

    def use_unstaged?
      ENV['UNSTAGED']
    end

    def manifest(options = {})
      unstaged = options.delete(:unstaged) || use_unstaged?
      parse_diff_index_data(diff_index(staged: !unstaged, ref: 'HEAD'))
    end

    def staged_manifest
      manifest(unstaged: false)
    end
    alias_method :commit_manifest, :staged_manifest

    def unstaged_manifest
      manifest(unstaged: true)
    end

    def diff_index(options = {})
      options = DEFAULT_DIFF_INDEX_OPTIONS.merge(options)

      cmd = %w(diff-index -C -M -B)
      cmd << '--cached' if options[:staged]
      cmd << options.delete(:ref) || 'HEAD'

      command(*cmd).output.strip
    end

  private

    def git
      @git ||= SystemUtils::Command.new('git')
    end

    def while_stashed(&block)
      fail ArgumentError, 'Missing required block' unless block_given?
      begin
        stash
        yield
      ensure
        unstash
      end
    end

    def run_while_stashed(cmd)
      while_stashed { system(cmd) }
      $? == 0
    end

    def parse_diff_index_data(index)
      index.split(/\n+/).collect { |data| Repository::File.new(data) }
    end
  end
end
