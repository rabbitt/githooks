require 'pathname'

if RUBY_ENGINE == 'jruby'
  class Pathname
    def realpath(basedir = nil)
      unless (path = java_realpath(basedir)).exist?
        fail Errno::ENOENT, path.to_s
      end
      path
    end

    def realdirpath(basedir = nil)
      java_realpath(basedir)
    end

    def java_realpath(basedir = nil)
      if basedir && !@path.start_with?('/')
        path = self.class.new(basedir).realpath + @path
      else
        path = @path.to_s
      end

      self.class.new java.io.File.new(path.to_s).canonical_path
    end
    private :java_realpath
  end
end
