require "fileutils"
require "find"
require "fog"

class BlobStore
  def initialize(connection_config, directory_key, cdn=nil, root_dir=nil)
    @root_dir = root_dir
    @connection_config = connection_config
    @directory_key = directory_key
    @cdn = cdn
  end

  def local?
    @connection_config[:provider].downcase == "local"
  end

  def files
    dir.files
  end

  def exists?(sha1)
    !file(sha1).nil?
  end

  def cp_to_local(source_sha, destination_path)
    FileUtils.mkdir_p(File.dirname(destination_path))
    File.open(destination_path, "w") do |file|
      (@cdn || files).get(key_from_sha1(source_sha)) do |*chunk|
        file.write(chunk[0])
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

  def cp_from_local(source_path, destination_sha, make_public=false)
    File.open(source_path) do |file|
      files.create(
        :key => key_from_sha1(destination_sha),
        :body => file,
        :public => make_public,
      )
    end
  end

  def delete(sha1)
    blob_file = file(sha1)
    blob_file.destroy if blob_file
  end

  def key_from_sha1(sha1)
    sha1 = sha1.to_s.downcase
    key = File.join(sha1[0..1], sha1[2..3], sha1)
    if @root_dir
      key = File.join(@root_dir, key)
    end
    key
  end

  def download_uri(sha1)
    file = file(sha1)
    return nil unless file
    file.url(Time.now + 3600)
  end

  def file(sha1)
    files.head(key_from_sha1(sha1))
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
end