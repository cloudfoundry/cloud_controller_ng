require "fileutils"
require "find"

class BlobStore
  def initialize(connection_config, directory_key)
    @connection_config = connection_config
    @directory_key = directory_key
  end

  def local?
    @connection_config[:provider].downcase == "local"
  end

  def files
    dir.files
  end

  def exists?(sha1)
    files.head(key_from_sha1(sha1))
  end

  def cp_to_local(sha1, local_destination)
    FileUtils.mkdir_p(File.dirname(local_destination))
    File.open(local_destination, "w") do |file|
      files.get(key_from_sha1(sha1)) do |chunk, _, _|
        file.write(chunk)
      end
    end
  end

  def cp_r_from_local(local_dir_path)
    Find.find(local_dir_path).each do |local_file_path|
      next unless File.file?(local_file_path)

      sha1 = Digest::SHA1.file(path).hexdigest
      next if exists?(sha1)

      cp_from_local(local_file_path, sha1)
    end
  end

  def cp_from_local(path, sha1)
    File.open(path) do |file|
      files.create(
        :key => key_from_sha1(sha1),
        :body => file,
        :public => false,
      )
    end
  end

  private

  def dir
    @dir ||= connection.directories.create(:key => @directory_key, :public => false)
  end

  def connection
    options = @connection_config
    options = options.merge(:endpoint => "") if local?
    Fog::Storage.new(options)
  end

  def key_from_sha1(sha1)
    sha1 = sha1.to_s.downcase
    File.join(sha1[0..1], sha1[2..3], sha1)
  end
end