class Array
  def extract_options
    self.last.is_a?(Hash) ? self.pop : {}
  end
end