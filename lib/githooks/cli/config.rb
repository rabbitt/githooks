require 'thor'
require 'githooks/repository'

module GitHooks
  module CLI
    class Config < Thor
      VALID_CONFIG_OPTIONS = Repository::Config::OPTIONS.keys.freeze

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
      def get(option) # rubocop:disable MethodLength, AbcSize
        unless VALID_CONFIG_OPTIONS.include? option
          puts "Invalid option '#{option}': expected one of #{VALID_CONFIG_OPTIONS.join(', ')}"
          return 1
        end

        GitHooks.verbose = !!options['verbose']
        GitHooks.debug   = !!options['debug']

        repository  = Repository.new(options['repo'])
        config_data = repository.config.get(option, global: options['global'])
        config_data ||= 'not set'

        puts "Repository [#{repository.path.basename}]"
        Array(config_data).flatten.each do |value|
          puts "  #{option} = #{value}"
        end
      end

      desc :set, 'Sets the configuration value '
      method_option :'overwrite-all', { # rubocop:disable BracesAroundHashParameters
        aliases: '-O',
        type: :boolean,
        desc: 'overwrite all existing values.',
        default: false
      }
      def set(option, value) # rubocop:disable AbcSize
        GitHooks.verbose = !!options['verbose']
        GitHooks.debug   = !!options['debug']

        Repository.new(options['repo']).config.set(
          option, value,
          global:    options['global'],
          overwrite: options['overwrite-all']
        ).status.success?
      rescue ArgumentError => e
        puts e.message
      end

      desc :unset, 'Unsets a configuration value'
      def unset(option, value = nil) # rubocop:disable AbcSize
        GitHooks.verbose = !!options['verbose']
        GitHooks.debug   = !!options['debug']

        Repository.new(options['repo']).config.unset(
          option, value, global: options['global']
        )
      rescue ArgumentError => e
        puts e.message
      end

      desc :list, 'Lists all githooks configuration values'
      def list # rubocop:disable AbcSize
        GitHooks.verbose = !!options['verbose']
        GitHooks.debug   = !!options['debug']

        repository = Repository.new(options['repo'])
        githooks   = repository.config.list(global: options['global'])['githooks']
        return unless githooks

        githooks.each do |path, data|
          key_size, value_size = data.keys.collect(&:size).max, data.values.collect(&:size).max
          display_format = "    %-#{key_size}s = %-#{value_size}s\n"

          puts "Repository [#{File.basename(path)}]"
          printf display_format, 'Repo Path', path

          data.each { |key, value|
            Array(value).flatten.each do |v|
              printf display_format, key.tr('-', ' ').titleize, v
            end
          }
        end
      end
    end
  end
end
