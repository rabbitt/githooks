=begin
Copyright (C) 2013 Carl P. Corliss

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
=end

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
      tr!('-', '_')
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
      tr!('_', '-')
    end
  end
end
