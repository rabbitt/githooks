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
  class Repository
    class Config
      OPTIONS = {
        'hooks-path'       => { type: :path, multiple: false },
        'script'           => { type: :path, multiple: false },
        'pre-run-execute'  => { type: :path, multiple: true },
        'post-run-execute' => { type: :path, multiple: true },
      }.freeze unless defined? OPTIONS

      OPTIONS.keys.each do |name|
        method_name = name.tr('-', '_')
        class_eval(<<-EOS, __FILE__, __LINE__ + 1)
          def #{method_name}(options = {})
            result = get('#{name}', options)
            OPTIONS['#{name}'][:multiple] ? [result].flatten.compact : result
          end
        EOS
      end

      def initialize(repository)
        @repository = repository
        @config = nil
      end

      def [](option)
        send(option.to_s.tr('-', '_'))
      end

      def set(option, value, options = {}) # rubocop:disable CyclomaticComplexity, MethodLength, PerceivedComplexity, AbcSize
        option    = normalize_option(option)
        repo      = options.delete(:repo_path) || @repository.path
        var_type  = "--#{OPTIONS[option][:type]}"
        add_type  = OPTIONS[option][:multiple] ? '--add' : '--replace-all'
        overwrite = !!options.delete(:overwrite)

        global    = (opt = options.delete(:global)).nil? ? false : opt
        global    = global ? '--global' : '--local'

        if OPTIONS[option][:type] == :path
          new_path = Pathname.new(value)
          unless new_path.exist?
            puts "Unable to set option option #{option} for [#{repo}]:"
            puts "  Path does not exist: #{new_path}"
            fail ArgumentError
          end
        else
          fail ArgumentError unless Pathname.new(value).executable?
        end

        value = Pathname.new(value).realpath.to_s

        if overwrite && !self[option].nil? && !self[option].empty?
          puts "Overwrite requested for option '#{option}'" if GitHooks.verbose
          unset(option, chdir: repo, global: global)
        end

        option = "githooks.#{repo}.#{option}"
        git(global, var_type, add_type, option, value, chdir: repo).tap do |result|
          puts "Added option #{option} with value #{value}" if result.status.success?
          @config = nil # reset config
        end
      end

      def remove_section(options = {})
        repo    = options.delete(:repo_path) || @repository.path
        global  = (opt = options.delete(:global)).nil? ? false : opt
        global  = global ? '--global' : '--local'
        @config = nil # reset config
        git(global, '--remove-section', "githooks.#{repo}", chdir: repo)
      end

      def unset(option, *args) # rubocop:disable AbcSize
        options = args.extract_options!
        global  = (opt = options.delete(:global)).nil? ? false : opt
        global  = global ? '--global' : '--local'
        option  = "githooks.#{repo}.#{normalize_option(option)}"

        value_regex = args.first

        if options.delete(:all) || value_regex.nil?
          git(global, '--unset-all', option, options)
        else
          git(global, '--unset', option, value_regex, options)
        end

        @config = nil # reset config

        result.status.success?
      end

      def get(option, options = {})
        option = normalize_option(option)

        begin
          repo = options[:repo_path] || @repository.path
          return unless (value = list(options)['githooks'][repo.to_s][option])
          OPTIONS[option][:type] == :path ? Pathname.new(value) : value
        rescue NoMethodError
          nil
        end
      end

      def list(options = {})
        config(chdir: options.delete(:repo_path) || options.delete(:chdir))
      end

      def inspect
        opts = OPTIONS.keys.collect { |k| ":'#{k}'=>#{get(k).inspect}" }.join(' ')
        format '<%s:0x%0x014 %s>', self.class.name, (__id__ * 2), opts
      end

    private

      def normalize_option(option)
        unless OPTIONS.keys.include? option
          fail ArgumentError, "Unexpected option '#{option}': expected one of: #{OPTIONS.keys.join(', ')}"
        end

        option.to_s
      end

      def git(*args)
        options = args.extract_options!
        args.push(options.merge(chdir: options[:repo_path] || options[:chdir] || @repository.path))
        @repository.git(:config, *args)
      end

      def config(*args) # rubocop:disable AbcSize
        @config ||= begin
          raw_config = git('--list', *args).output.split("\n").sort.uniq
          raw_config.each_with_object({}) do |line, hash|
            key, value = line.split(/\s*=\s*/)
            key_parts = key.git_option_path_split

            ptr = hash[key_parts.shift] ||= {}
            ptr = ptr[key_parts.shift] ||= {} until key_parts.size == 1

            key = key_parts.shift
            case ptr[key]
              when nil then ptr[key] = value
              when Array then ptr[key] << value
              else ptr[key] = [ptr[key], value].flatten
            end

            hash
          end
        end
      end
    end
  end
end
