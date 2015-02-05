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
