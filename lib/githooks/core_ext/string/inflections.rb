=begin
  Mostly borrowed from Rails' ActiveSupport::Inflections
=end

class String
  def constantize
    names = split('::')
    names.shift if names.empty? || names.first.empty?

    names.inject(Object) do |obj, name|
      obj.const_defined?(name) ? obj.const_get(name) : obj.const_missing(name)
    end
  rescue NameError => e
    raise unless e.message =~ /uninitialized constant/
  end

  def camelize
    dup.camelize!
  end

  def camelize!
    tap do
      gsub!('-', '_')
      sub!(/^[a-z\d]*/, &:capitalize)
      gsub!(/(?:_|(\/))([a-z\d]*)/i) { "#{$1}#{$2.capitalize}" }
      gsub!('/', '::')
    end
  end

  def underscore
    dup.underscore!
  end

  def underscore!
    tap do
      gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
      gsub!(/([a-z\d])([A-Z])/, '\1_\2')
      tr!('-', '_')
      downcase!
    end
  end

  def titleize
    dup.titleize!
  end
  alias_method :titlize, :titleize

  def titleize!
    tap do
      replace(
        split(/\b/).collect(&:capitalize).join
      )
    end
  end
  alias_method :titlize!, :titleize!

  def dasherize
    dup.dasherize!
  end

  def dasherize!
    tap do
      underscore!
      gsub!(/_/, '-')
    end
  end
end
