# A "resource" is typically represented as a Hash with two attributes:
# :size (bytes)
# :sha1 (string)
# If there are other attributes, such as in legacy calls to "match_resources",
# they will be ignored and preserved.

require "fog"
require "httpclient"
require "steno"

class VCAP::CloudController::ResourcePool
  attr_accessor :minimum_size, :maximum_size
  attr_reader :blobstore

  class << self
    attr_accessor :instance
  end

  def initialize(config = {})
    options = config[:resource_pool] || {}
    @cdn = options[:cdn]

    @blobstore = CloudController::Blobstore::Client.new(
        options[:fog_connection],
        options[:resource_directory_key] || "cc-resources"
    )

    @minimum_size = options[:minimum_size] || 0
    @maximum_size = options[:maximum_size] || 512 * 1024 * 1024 # MB
  end

  def match_resources(descriptors)
    descriptors.select { |h| resource_known?(h) }
  end

  # Adds everything under source directory +dir+ to the resource pool.
  def add_directory(dir)
    unless File.exists?(dir) && File.directory?(dir)
      raise ArgumentError, "Source directory #{dir} is not valid"
    end

    pattern = File.join(dir, "**", "*")
    files = Dir.glob(pattern, File::FNM_DOTMATCH).select do |f|
      resource_allowed?(f)
    end

    files.each do |path|
      add_path(path)
    end
  end

  def add_path(path)
    sha1 = Digest::SHA1.file(path).hexdigest
    key = key_from_sha1(sha1)
    return if blobstore.files.head(sha1)

    File.open(path) do |file|
      blobstore.files.create(
        :key    => key,
        :body   => file,
        :public => false,
      )
    end
  end

  def resource_sizes(resources)
    sizes = []
    resources.each do |descriptor|
      key = key_from_sha1(descriptor["sha1"])
      if (head = blobstore.files.head(key))
        entry = descriptor.dup
        entry["size"] = head.content_length
        sizes << entry
      end
    end
    sizes
  end

  def copy(descriptor, destination)
    if resource_known?(descriptor)
      logger.debug "resource_pool.sync.start", :resource => descriptor, :destination => destination
      overwrite_destination_with!(descriptor, destination)
    else
      logger.warn "resource_pool.sync.failed", :unknown_resource => descriptor, :destination => destination
      raise ArgumentError, "Can not copy bits we do not have #{descriptor}"
    end
  end

  private

  def logger
    @logger ||= Steno.logger("cc.resource_pool")
  end

  def resource_known?(descriptor)
    size = descriptor["size"]
    if size_allowed?(size)
      key = key_from_sha1(descriptor["sha1"])
      blobstore.files.head(key)
    end
  end

  def resource_allowed?(path)
    stat = File.stat(path)
    File.file?(path) && !stat.symlink? && size_allowed?(stat.size)
  end

  def size_allowed?(size)
    size && size > minimum_size && size < maximum_size
  end

  # Called after we sanity-check the input.
  # Create a new path on disk containing the resource described by +descriptor+
  def overwrite_destination_with!(descriptor, destination)
    FileUtils.mkdir_p File.dirname(destination)
    s3_key = key_from_sha1(descriptor["sha1"])

    logger.debug "resource_pool.download.starting",
      :destination => destination

    start = Time.now

    if @cdn && @cdn[:uri]
      logger.debug "resource_pool.download.using-cdn"

      uri = "#{@cdn[:uri]}/#{s3_key}"
      for_real_uri = AWS::CF::Signer.is_configured? ? AWS::CF::Signer.sign_url(uri) : uri

      File.open(destination, "w") do |file|
        HTTPClient.new.get(for_real_uri) do |chunk|
          file.write(chunk)
        end
      end
    else
      File.open(destination, "w") do |file|
        blobstore.files.get(s3_key) do |chunk, _, _|
          file.write(chunk)
        end
      end
    end

    took = Time.now - start

    logger.debug "resource_pool.download.complete", :took => took,
      :destination => destination
  end

  def key_from_sha1(sha1)
    sha1 = sha1.to_s.downcase
    File.join(sha1[0..1], sha1[2..3], sha1)
  end
end
