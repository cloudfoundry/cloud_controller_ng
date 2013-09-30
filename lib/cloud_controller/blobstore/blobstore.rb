require "fileutils"
require "find"
require "fog"

class Blobstore
  def initialize(connection_config, directory_key, cdn=nil, root_dir=nil)
    @root_dir = root_dir
    @connection_config = connection_config
    @directory_key = directory_key
    @cdn = cdn
  end

  def local?
    @connection_config[:provider].downcase == "local"
  end

  def exists?(key)
    !file(key).nil?
  end

  def download_from_blobstore(source_key, destination_path)
    FileUtils.mkdir_p(File.dirname(destination_path))
    File.open(destination_path, "w") do |file|
      (@cdn || files).get(partitioned_key(source_key)) do |*chunk|
        file.write(chunk[0])
      end
    end
  end

  def cp_r_to_blobstore(source_dir)
    Find.find(source_dir).each do |path|
      next unless File.file?(path)

      sha1 = Digest::SHA1.file(path).hexdigest
      next if exists?(sha1)

      cp_to_blobstore(path, sha1)
    end
  end

  def cp_to_blobstore(source_path, destination_key)
    File.open(source_path) do |file|
      files.create(
        :key => partitioned_key(destination_key),
        :body => file,
        :public => local?,
      )
    end
  end

  def delete(key)
    blob_file = file(key)
    blob_file.destroy if blob_file
  end

  def download_uri(key)
    file = file(key)
    return nil unless file
    return download_uri_for_file(file)
  end

  def download_uri_for_file(file)
    if @cdn
      return @cdn.download_uri(file.key)
    end
    if file.respond_to?(:url)
      return file.url(Time.now + 3600)
    elsif file.respond_to?(:temp_signed_url)
      return file.temp_signed_url(3600, "GET")
    end
    return file.public_url
  end

  def file(key)
    files.head(partitioned_key(key))
  end

  # Deprecated should not allow to access underlying files
  def files
    dir.files
  end

  private
  def partitioned_key(key)
    key = key.to_s.downcase
    key = File.join(key[0..1], key[2..3], key)
    if @root_dir
      key = File.join(@root_dir, key)
    end
    key
  end

  def dir
    @dir ||= connection.directories.create(:key => @directory_key, :public => false)
  end

  def connection
    options = @connection_config

    # Special case for hp provider:
    # Deployment manifest symbol values are converted to strings when transfering deployment information.
    # We have to convert the hp_auth_version value to a symbol if present.    
    if options[:provider].downcase == "hp"
      begin
        options[:hp_auth_version] = options[:hp_auth_version].to_sym 
      rescue
      end
    end
    
    options = options.merge(:endpoint => "") if local?
    Fog::Storage.new(options)
  end
end