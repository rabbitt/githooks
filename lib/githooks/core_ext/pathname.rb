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

require 'pathname'

if RUBY_ENGINE == 'jruby'
  class Pathname
    def realpath(basedir = nil)
      java_realpath(basedir).tap do |path|
        fail Errno::ENOENT, path.to_s unless path.exist?
      end
    end

    def realdirpath(basedir = nil)
      java_realpath(basedir)
    end

    def java_realpath(basedir = nil)
      # rubocop:disable ElseAlignment, EndAlignment
      path = if basedir && @path[0] != '/'
        Pathname.new(basedir).realpath.join(@path)
      else
        @path.to_s
      end
      # rubocop:enable ElseAlignment, EndAlignment

      self.class.new java.io.File.new(path.to_s).canonical_path
    end
    private :java_realpath
  end
end

class Pathname
  def include?(component)
    to_s.split(File::SEPARATOR).include?(component)
  end

  def exclude?(component)
    !include?(component)
  end
end
