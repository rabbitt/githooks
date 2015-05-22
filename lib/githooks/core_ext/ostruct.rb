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

require 'ostruct'
require 'thor/core_ext/hash_with_indifferent_access'

class IndifferentAccessOpenStruct < OpenStruct
  def new_ostruct_member(name)
    return super unless name.to_s.include? '-'

    original_name, sanitized_name = name, name.to_s.gsub('-', '_').to_sym
    return if respond_to?(sanitized_name)

    define_singleton_method(sanitized_name) { @table[original_name] }
    define_singleton_method("#{sanitized_name}=") { |x| @table[original_name] = x }
  end

  def [](k)
    public_send(k)
  end

  def []=(k, v)
    public_send("#{k}=", v)
  end

  def to_h
    Thor::CoreExt::HashWithIndifferentAccess.new(@table)
  end
end
