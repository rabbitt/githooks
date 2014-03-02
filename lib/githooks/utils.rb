# encoding: utf-8
require 'pathname'

module GitHooks
  module Utils
    def which(name)
      find_bin(name).first
    end
    module_function :which

    def find_bin(name)
      # rubocop:disable MultilineBlockChain, Blocks
      ENV['PATH'].split(/:/).collect {
        |path| Pathname.new(path) + name.to_s
      }.select { |path|
        path.exist? && path.executable?
      }.collect(&:to_s)
      # rubocop:enable MultilineBlockChain, Blocks
    end
    module_function :find_bin
  end
end
