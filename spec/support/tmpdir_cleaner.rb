class TmpdirCleaner
  def self.dir_paths
    @dir_paths ||= []
  end

  def self.clean_later(dir_path)
    dir_path = File.realpath(dir_path)
    tmpdir_path = File.realpath(Dir.tmpdir)

    unless dir_path.start_with?(tmpdir_path)
      raise ArgumentError, "dir '#{dir_path}' is not in #{tmpdir_path}"
    end
    dir_paths << dir_path
  end

  def self.clean
    FileUtils.rm_rf(dir_paths)
    dir_paths.clear
  end

  def self.mkdir
    dir_path = Dir.mktmpdir
    clean_later(dir_path)
    yield(dir_path)
    dir_path
  end
end
