require 'colorize'

module Colorize
  module ClassMethods
    unless respond_to? :disable_colorization_without_tty_detection
      alias_method :disable_colorization_without_tty_detection, :disable_colorization
    end

    def disable_colorization(value = nil)
      # disable colorization when we don't have a tty on STDOUT
      return true unless value || STDOUT.tty?
      disable_colorization_without_tty_detection(value)
    end
  end

  module InstanceMethods
    def success!
      light_green
    end

    def failure!
      light_red
    end

    def unknown!
      light_yellow
    end
    alias_method :warning!, :unknown!
  end
end
