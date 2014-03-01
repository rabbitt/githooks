require 'pathname'

module GitHooks
  module Utils
    extend self

    def which(name)
      find_bin(name).first
    end

    def find_bin(name)
      ENV['PATH'].split(/:/).collect { |path|
        Pathname.new(path) + name.to_s
      }.select { |path|
        path.exist? && path.executable?
      }.collect(&:to_s)
    end
  end
end
