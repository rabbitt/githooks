class String
  def constantize()
    names = self.split('::')
    names.shift if names.empty? || names.first.empty?

    names.inject(Object) { |obj, name|
      obj = obj.const_defined?(name) ? obj.const_get(name) : obj.const_missing(name)
    }
  end

  def camelize()
    self.dup.camelize!
  end

  def camelize!()
    self.replace(self.split(/[\W_]+/).collect(&:capitalize).join)
  end

  def underscore!()
    self.tap {|word|
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      word.tr!("-", "_")
      word.downcase!
    }
  end

  def underscore()
    self.dup.underscore!
  end

  def dasherize!()
    self.underscore!.gsub!(/_/, '-')
  end

  def dasherize()
    self.dup.dasherize!
  end
end
