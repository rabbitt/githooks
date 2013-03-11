require 'delegate'

module GitHooks
  class Hook < DelegatorClass(Hook::Base)

    def initialize(type)
      @hook = type.camelize.constantize.new(*ARGV)
    end

    def __getobj__() @hook; end


    def match_files_on(type = :and, options)
      raise ArgumentError, "options should be a hash" unless options.is_a? Hash
      raise ArgumentError, "Match Filter has invalid selection operator '#{type}' (should be: :or, :and, or :not)" unless [:and, :or, :not].include? type
      (@filters||=[]) << [type, options.to_a]
    end

    def match(check_files)
      @filters.inject([])  {|matches, filter|
        case filter.first
          when :not then @files.reject { |f| @match.all? {|match| match_file(f, *filter[1..-1]) } }
          when :and then @files.select { |f| @match.all? {|match| match_file(f, *filter[1..-1]) } }
          when :or then @files.select { |f| @match.any? {|match| match_file(f, *filter[1..-1]) } }
          else raise ArgumentError, "Match Filter missing required selection operator (:or, :and, or :not)"
        end
      }
    end

    def match_file(file, matchtype, matchvalue)
      case matchtype
        when :name then
          matchvalue.is_a?(Regexp) ? file[:path] =~ matchvalue : file[:path] == matchvalue
        when :type then
          matchvalue.is_a?(Array) ? matchvalue.include?(file[:type]) : matchvalue == file[:type]
        when :mode then
          matchvalue & file[:to][:mode] == matchvalue
        when :sha then
          file[:to][:mode] == matchvalue
        when :score then
          file[:score] == matchvalue
      end
    end

    class << self
      def register(hook, &block)
      end
    end

  end
end