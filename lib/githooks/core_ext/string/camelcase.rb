class String
  def camelize()
    self.dup.camelize!
  end

  def camelize!()
    self.replace(self.split(/[\W_]+/).collect(&:capitalize).join)
  end
end