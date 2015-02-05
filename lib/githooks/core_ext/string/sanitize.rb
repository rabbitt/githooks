require_relative '../array/extract_options'

class String
  def strip_empty_lines!
    replace(strip_empty_lines)
  end

  def strip_empty_lines
    split(/\n/).reject { |s| s !~ /\S/ }.join("\n")
  end

  def strip_non_printable!
    replace(strip_non_printable)
  end

  def strip_non_printable
    gsub(/[^[:print:] \n\t\x1b]/, '')
  end

  def strip_colors!
    replace(strip_colors)
  end

  def strip_colors
    gsub(/\x1b\[\d+(?:;\d+)?m/, '')
  end

  def sanitize!(*methods)
    options = methods.extract_options!

    map = {
      strip:         :strip!,
      empty_lines:   :strip_empty_lines!,
      non_printable: :strip_non_printable!,
      colors:        :strip_colors!
    }

    methods = map.keys if methods.empty? || methods.include?(:all)
    methods -= Array(options.delete(:except)) if options[:except]

    methods.collect(&:to_sym).each do |method|
      send(map[method]) if map[method]
    end

    self
  end

  def sanitize(*methods)
    dup.sanitize!(*methods)
  end
end
