class Object
  def deep_dup
    Marshal.load(Marshal.dump(self))
  rescue TypeError => e
    raise e unless e.message.include? "can't dump"
    dup
  end
end
