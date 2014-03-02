class Array
  def select_with_index(regexp = nil, &block)
    [].tap do |collection|
      each_with_index do |node, index|
        if regexp.is_a? Regexp
          collection << [index, node] if node =~ regexp
        elsif block_given?
          collection << [index, node] if yield(node)
        end
      end
    end
  end
end
