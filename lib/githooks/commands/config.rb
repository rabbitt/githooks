require 'thor'
require 'githooks/repository'

module GitHooks
  module CLI
    class Config < Thor
      VALID_CONFIG_OPTIONS = %w( path script pre-run-execute post-run-execute )

      # class_option :verbose, type: :boolean, desc: 'verbose output', default: false
      # class_option :debug, type: :boolean, desc: 'debug output', default: false

      class_option :global, aliases: '-G', type: :boolean, desc: 'use global config', default: false
      class_option :hooks, { # rubocop:disable BracesAroundHashParameters
        type: :array,
        desc: 'choose specific hooks to affect',
        enum: %w( pre-commit commit-msg )
      }
      class_option :repo, { # rubocop:disable BracesAroundHashParameters
        aliases: '-r',
        type: :string,
        desc: 'Repository path to look up configuration values for.'
      }

      desc :get, 'display the value for a configuration option'
      def get(option_name) # rubocop:disable MethodLength, AbcSize
        unless VALID_CONFIG_OPTIONS.include? option_name
          puts "Invalid option '#{option_name}': expected one of #{VALID_CONFIG_OPTIONS.join(', ')}"
          return 1
        end

        GitHooks.verbose = !!options['verbose']
        GitHooks.debug   = !!options['debug']
        options['repo'] ||= GitHooks::Repository.root_path

        repo_data = GitHooks::Repository::Config.new.get(
          option_name,
          repo_path: options['repo'],
          global: options['global']
        )

        if repo_data.nil?
          puts "Repository [#{options['repo']}] option '#{option_name}' is currently not set."
          return
        end

        Array(repo_data).flatten.each do |value|
          value ||= 'not set'
          puts "#{option_name}: #{value}"
        end
      end

      desc :set, 'Sets the configuration value '
      method_option :'overwrite-all', { # rubocop:disable BracesAroundHashParameters
        aliases: '-O',
        type: :boolean,
        desc: 'overwrite all existing values.',
        default: false
      }
      def set(option_name, option_value) # rubocop:disable AbcSize
        GitHooks.verbose = !!options['verbose']
        GitHooks.debug   = !!options['debug']
        options['repo'] ||= GitHooks::Repository.root_path

        GitHooks::Repository::Config.new.set(
          option_name,
          option_value,
          repo_path: options['repo'],
          global: options['global'],
          overwrite: options['overwrite-all']
        ).status.success?
      rescue ArgumentError => e
        puts e.message
      end

      desc :unset, 'Unsets a configuration value'
      def unset(option_name, option_value = nil) # rubocop:disable AbcSize
        GitHooks.verbose = !!options['verbose']
        GitHooks.debug   = !!options['debug']
        options['repo'] ||= GitHooks::Repository.root_path

        GitHooks::Repository::Config.new.unset(
          option_name,
          option_value,
          repo_path: options['repo'],
          global: options['global']
        )
      rescue ArgumentError => e
        puts e.message
      end

      desc :list, 'Lists all githooks configuration values'
      def list # rubocop:disable AbcSize
        GitHooks.verbose = !!options['verbose']
        GitHooks.debug   = !!options['debug']

        options['repo'] ||= GitHooks::Repository.root_path
        config = GitHooks::Repository::Config.new

        githooks = config.list(global: options['global'], repo_path: options['repo'])['githooks']
        return unless githooks

        githooks.each do |path, data|
          puts "Repository #{path}:"
          key_size, value_size = data.keys.collect(&:size).maximum, data.values.collect(&:size).maximum
          data.each do |key, value|
            [value].flatten.each do |v|
              printf "    %-#{key_size}s : %-#{value_size}s\n", key, v
            end
          end
        end
      end
    end
  end
end
