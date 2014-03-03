require 'awesome_print'
module GitHooks
  module CLI
    class Config < Thor
      VALID_CONFIG_OPTIONS = %w( path script pre-run-execute post-run-execute )

      class_option :global, type: :boolean, desc: 'use global config', default: false
      class_option :hooks, { # rubocop:disable BracesAroundHashParameters
        type: :array,
        desc: 'choose specific hooks to affect',
        enum: %w( pre-commit commit-msg )
      }
      class_option :repo, { # rubocop:disable BracesAroundHashParameters
        type: :string,
        default: GitHooks::Repository.root_path,
        desc: 'Repository path to look up configuration values for.'
      }

      desc :get, 'display the value for a configuration option'
      def get(option_name)
        unless VALID_CONFIG_OPTIONS.include? option_name
          puts "Invalid option '#{option_name}': expected one of #{VALID_CONFIG_OPTIONS.join(', ')}"
          return 1
        end
        repo_data = GitHooks::Repository::Config.new.get(
          option_name,
          repo_path: options['repo'], global: options['global']
        )
        if repo_data.nil?
          puts "Repository [#{options['repo']}] option '#{option_name}' is currently not set."
          return
        end
        [repo_data].flatten.each do |value|
          puts "#{option_name}: #{value || 'not set'}"
        end
      end

      desc :set, 'Sets the configuration value '
      def set(option_name, option_value)
        GitHooks::Repository::Config.new.set(
          option_name,
          option_value,
          repo_path: options['repo'], global: options['global']
        ).status.success?
      rescue ArgumentError => e
        puts e.message
      end

      desc :unset, 'Unsets a configuration value'
      def unset(option_name)
        GitHooks::Repository::Config.new.unset(
          option_name,
          repo_path: options['repo'],
          global: options['global']
        )
      rescue ArgumentError => e
        puts e.message
      end

      desc :list, 'Lists all githooks configuration values'
      def list
        config = GitHooks::Repository::Config.new
        githooks = config.list(global: options['global'], repo_path: options['repo'])['githooks']
        githooks.each do |path, data|
          puts "Repository #{path}:"
          key_size, value_size = data.keys.collect(&:size).max, data.values.collect(&:size).max
          data.each do |key, value|
            [value].flatten.each do |v|
              printf "    %-#{key_size}s : %-#{value_size}s\n", key, v
            end
          end
        end if githooks
      end
    end
  end
end
