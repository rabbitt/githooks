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
    class Config # rubocop:disable ClassLength
      HOOKS = GitHooks::Hook::VALID_PHASES.dup.freeze

      class Option
        attr_reader :type, :multi
        alias_method :multi?, :multi

        def initialize(name, options = {})
          @name  = name
          @type  = options.delete(:type) || :path
          @multi = !options.delete(:multi)
        end

        def path?
          type == :path
        end

        def name?(name)
          [key_name, config_name].include? name.to_s
        end

        def title_name
          @name.titleize
        end

        def key_name
          @name.underscore
        end

        def config_name
          @name.dasherize
        end

        def method_name
          key_name.to_sym
        end
      end

      class << self
        attr_reader :config_options
        def option(name, options = {})
          Option.new(name.to_s, options).tap { |opt|
            (@config_options ||= {})[opt.key_name] = opt
            define_method(opt.method_name) do |hook|
              get(hook, opt.config_name)
            end
          }
        end
      end

      option :bootstrapper
      option :'hooks-path'
      option :script
      option :'pre-run-execute', multi: true
      option :'post-run-execute', multi: true

      def initialize(repository)
        @repository = repository
      end

      def list
        config
      end

      def get(hook, option)
        option = config_option(option)
        if hook.nil?
          get_default_option(option.key_name)
        elsif option.multi?
          hook_options    = Array(get_hook_option(hook, option.key_name))
          default_options = Array(get_default_option(option.key_name))
          (default_options - hook_options) | hook_options
        else
          get_hook_option(hook, option.key_name) || get_default_option(option.key_name)
        end
      end

      def get_default_option(option)
        option = config_option(option)
        return unless (value = list[option.key_name])
        option.path? ? Pathname.new(value) : value
      end

      def get_hook_option(hook, option)
        option = config_option(option)
        puts "looking for: list[#{hook.inspect}][#{option.key_name.inspect}]"
        return unless (value = list[hook][option.key_name])
        option.path? ? Pathname.new(value) : value
      end

      def set_default_option(option, value, options = {})
        set(nil, option, value, options)
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      def set_hook_option(hook, option, value, options = {})
        type      = "--#{config_option(option).type}"
        mode      = config_option(option).multi? ? '--add' : '--replace-all'
        overwrite = !!options.delete(:overwrite)

        unless HOOKS.include? hook.to_s
          fail ArgumentError, "Invalid hook #{hook}; expected one of #{HOOKS.join(', ')}"
        end

        if config_option(option).path?
          unless (new_path = Pathname.new(value)).exist?
            $stderr.puts "Unable to set option option #{option} for [#{@repository.name}]:"
            $stderr.puts "  Path does not exist: #{new_path}"
            fail ArgumentError
          end
        else
          fail ArgumentError unless Pathname.new(value).executable?
        end

        value = Pathname.new(value).realpath.to_s

        if overwrite && get(hook, option).to_s =~ /\S/
          puts "Overwrite requested for option '#{option}'" if GitHooks.verbose
          unset(option)
        end

        ensure_config_reset do
          option = key(hook, option)
          git?(type, mode, option, value).tap do |result|
            puts "Added option #{option} with value #{value}" if result
          end
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      def remove_hook(hook)
        ensure_config_reset do
          git?(:'--remove-section', key(hook))
        end
      end

      def remove_all
        ensure_config_reset do
          config.keys.all? { |hook| remove_hook(hook) }
        end
      end

      def unset(hook, option, options)
        option_name = key(hook, config_option(option).config_name)
        value_regex = args.first

        ensure_config_reset do
          if options.delete(:all) || value_regex.nil?
            git?('--unset-all', option_name, options)
          else
            git?('--unset', option_name, value_regex, options)
          end
        end
      end

      def key(*args)
        ['githooks', *args].join('.')
      end

      def inspect
        if config.empty?
          options = 'hooks => { }'
        else
          options = 'hooks => {' << config.collect { |hook, opts|
            "#{hook.inspect} => {#{opts.collect do |key, value|
              "#{key.inspect}=>#{value.inspect}"
            end.join(', ')}}"
          }.join(', ') << '}'
        end
        format '<%s:0x%0x014 %s>', self.class.name, (__id__ * 2), options
      end

    private

      def git(*args, &block)
        args.push(args.extract_options!.merge(chdir: @repository.path))
        @repository.git(:config, '--local', *args, &block)
      end

      def git?(*args, &block)
        git(*args, &block).status.success?
      end

      def config_options
        self.class.config_options
      end

      def config_option_names
        config_options.values.collect(&:key_name)
      end

      def config_option(option)
        config_options.values.find { |opt| opt.name? option }.tap { |opt|
          unless opt
            fail ArgumentError, "Unexpected option `#{option}': expected one of: #{config_option_names.join(', ')}"
          end
        }
      end

      def ensure_config_reset
        fail 'Missing required block' unless block_given?
        return yield
      ensure
        @config = nil
      end

      def config(*args) # rubocop:disable Metrics/AbcSize
        @config ||= begin
          raw_config = git('--list', *args).output.split("\n").sort.uniq
          raw_config.each_with_object({}) do |line, hash|
            key, value = line.split(/\s*=\s*/)

            section, *subsection, option = key.split('.')
            subsection = (hash[section] ||= {})[subsection.join('.')] ||= {}

            if subsection[option].nil?
              # not previously set, so set it to whatever it's current value is
              subsection[option] = value
            else
              # otherwise, merge it with any previous value(s)
              subsection[option] = Array(subsection[option]) << value
            end
          end
        end

        @config['githooks'] || {}
      end
    end
  end
end
