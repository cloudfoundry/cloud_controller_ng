require "fileutils"
require "find"
require "fog"

class BlobStore
  def initialize(connection_config, directory_key)
    @connection_config = connection_config.to_hash
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

  def cp_to_local(source_sha, destination_path)
    FileUtils.mkdir_p(File.dirname(destination_path))
    File.open(destination_path, "w") do |file|
      files.get(key_from_sha1(source_sha)) do |chunk, _, _|
        file.write(chunk)
      end
    end
  end

  def cp_r_from_local(source_dir)
    Find.find(source_dir).each do |path|
      next unless File.file?(path)

      sha1 = Digest::SHA1.file(path).hexdigest
      next if exists?(sha1)

      cp_from_local(path, sha1)
    end
  end

  def cp_from_local(source_path, destination_sha)
    File.open(source_path) do |file|
      files.create(
        :key => key_from_sha1(destination_sha),
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