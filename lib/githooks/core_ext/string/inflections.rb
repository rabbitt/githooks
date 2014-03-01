=begin
  Mostly borrowed from Rails' ActiveSupport::Inflections
=end

class String
  def constantize()
    names = self.split('::')
    names.shift if names.empty? || names.first.empty?

    begin
      names.inject(Object) { |obj, name|
        if obj.const_defined?(name)
          obj.const_get(name)
        else
          obj.const_missing(name)
        end
      }
    rescue NameError => e
      raise unless e.message =~ /uninitialized constant/
    end
  end

  def camelize()
    self.dup.camelize!
  end

  def camelize!()
    self.sub!(/^[a-z\d]*/, &:capitalize)
    self.gsub!(/(?:_|(\/))([a-z\d]*)/i) { "#{$1}#{$2.capitalize}" }
    self.gsub!('/', '::')
  end

  def underscore()
    self.dup.underscore!
  end

  def underscore!()
    self.tap {|word|
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      word.tr!("-", "_")
      word.downcase!
    }
  end

  def titleize
    self.dup.titleize!
  end
  alias :titlize :titleize

  def titleize!
    self.tap { |title|
      title.replace(title.split(/\b/).collect(&:capitalize).join)
    }
  end
  alias :titlize! :titleize!

  def dasherize()
    self.dup.dasherize!
  end

  def dasherize!()
    self.underscore!.gsub!(/_/, '-')
  end
end
