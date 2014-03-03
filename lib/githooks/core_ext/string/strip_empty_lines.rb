class String
  def strip_empty_lines!
    replace(split(/\n/).reject(&:empty?).join("\n"))
  end

  def strip_empty_lines
    dup.strip_empty_lines!
  end
end
