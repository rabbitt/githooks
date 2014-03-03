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
  class Repository::Config
    OPTIONS = {
      'path' => { type: :path, multiple: false },
      'script' => { type: :path, multiple: false },
      'pre-run-execute' => { type: :path, multiple: true },
      'post-run-execute' => { type: :path, multiple: true }
    }

    def initialize(path = Dir.getwd)
      @repository = Repository.instance(path)
    end

    OPTIONS.keys.each do |name|
      method_name = name.gsub(/-/, '_')
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def #{method_name}(options = {})
          get('#{name}', options)
        end
      EOS
    end

    def set(option, value, options = {}) # rubocop:disable CyclomaticComplexity, MethodLength
      unless OPTIONS.keys.include? option
        fail ArgumentError, "Unexpected option '#{option}': expected on of: #{OPTIONS.keys.join(', ')}"
      end

      repo     = options.delete(:repo_path) || repo_path
      global   = (opt = options.delete(:global)).nil? ? false : opt
      var_type = "--#{OPTIONS[option][:type]}"
      add_type = OPTIONS[option][:multiple] ? '--add' : '--replace-all'

      if option == 'path'
        new_path = Pathname.new(value)
        errors = []
        errors << 'path must be a real location' unless new_path.exist?
        errors << 'path must be a directory' unless new_path.directory?
        errors << 'path must have a Gemfile in it' unless (new_path + 'Gemfile').exist?
        errors << 'path must have a lib directory in it' unless (new_path + 'lib').exist?

        if errors.size > 0
          puts "Unable to change githooks path for [#{repo}]:"
          errors.each { |error| puts "  #{error}" }
          fail ArgumentError
        end
      else
        fail ArgumentError unless Pathname.new(value).executable?
      end

      option   = "githooks.#{repo}.#{option}"
      command(global ? '--global' : '--local', var_type, add_type, option, value, path: repo)
    end

    def unset(option, options = {})
      unless OPTIONS.keys.include? option
        fail ArgumentError, "Unexpected option '#{option}': expected on of: #{OPTIONS.keys.join(', ')}"
      end

      repo   = options.delete(:repo_path) || repo_path
      global = (opt = options.delete(:global)).nil? ? false : opt
      option = "githooks.#{repo}.#{option}"
      cmd    = options.delete(:all) ? '--unset-all' : '--unset'

      command(global ? '--global' : '--local', cmd, option, path: repo)
    end

    def get(option, options = {})
      unless OPTIONS.keys.include? option
        fail ArgumentError, "Unexpected option '#{option}': expected on of: #{OPTIONS.keys.join(', ')}"
      end

      repo     = options[:repo_path] || repo_path
      githooks = list(options)['githooks']

      githooks[repo][option] if githooks && githooks[repo] && githooks[repo][option]
    end

    def list(options = {}) # rubocop:disable MethodLength, CyclomaticComplexity
      repo   = options.delete(:repo_path) || repo_path
      global = (opt = options.delete(:global)).nil? ? false : opt

      config_list = command('--list', global ? '--global' : '--local', path: repo).output.split(/\n/)
      config_list.inject({}) do |hash, line|
        key, value = line.split(/\s*=\s*/)
        key_parts = key.split('.')

        ptr = hash[key_parts.shift] ||= {} # rubocop:disable IndentationWidth
        while key_parts.size > 1 && (part = key_parts.shift)
          ptr = ptr[part] ||= {} # rubocop:disable IndentationWidth
        end

        key = key_parts.shift
        case ptr[key]
          when nil then ptr[key] = value
          when Array then ptr[key] << value
          else ptr[key] = [ptr[key], value].flatten
        end

        hash
      end
    end

  private

    def repo_path
      @repository.root_path
    end

    def command(*args)
      args = ['config', *args].flatten
      @repository.command(*args)
    end

    def git
      @repository.git
    end
  end
end
