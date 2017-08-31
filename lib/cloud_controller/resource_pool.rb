# A "resource" is typically represented as a Hash with two attributes:
# :size (bytes)
# :sha1 (string)
# If there are other attributes, such as in legacy calls to "match_resources",
# they will be ignored and preserved.

require 'httpclient'
require 'steno'
require 'cloud_controller/blobstore/fog/providers'

class VCAP::CloudController::ResourcePool
  VALID_SHA_LENGTH = 40

  attr_accessor :minimum_size, :maximum_size
  attr_reader :blobstore

  class << self
    attr_accessor :instance
  end

  def initialize(config)
    options = config.get(:resource_pool) || {} # TODO: move default into config object?

    @blobstore = CloudController::Blobstore::ClientProvider.provide(
      options: options,
      directory_key: options.fetch(:resource_directory_key),
      root_dir: CloudController::DependencyLocator::RESOURCE_POOL_DIR,
    )

    @minimum_size = options[:minimum_size] || 0 # TODO: move default into config object?
    @maximum_size = options[:maximum_size] || 512 * 1024 * 1024 # MB #TODO: move default into config object?
  end

  def match_resources(descriptors)
    descriptors.select { |h| resource_known?(h) }
  end

  # Adds everything under source directory +dir+ to the resource pool.
  def add_directory(dir)
    unless File.exist?(dir) && File.directory?(dir)
      raise ArgumentError.new("Source directory #{dir} is not valid")
    end

    pattern = File.join(dir, '**', '*')
    files = Dir.glob(pattern, File::FNM_DOTMATCH).select do |f|
      resource_allowed?(f)
    end

    files.each do |path|
      add_path(path)
    end
  end

  def add_path(path)
    sha1 = Digester.new.digest_path(path)
    return if blobstore.exists?(sha1)

    blobstore.cp_to_blobstore(path, sha1)
  end

  def resource_sizes(resources)
    sizes = []
    resources.each do |descriptor|
      if (blob = blobstore.blob(descriptor['sha1']))
        entry = descriptor.dup
        entry['size'] = blob.attributes[:content_length]
        sizes << entry
      end
    end
    sizes
  end

  def copy(descriptor, destination)
    if resource_known?(descriptor)
      logger.debug 'resource_pool.sync.start', resource: descriptor, destination: destination

      logger.debug 'resource_pool.download.starting',
        destination: destination

      start = Time.now.utc

      blobstore.download_from_blobstore(descriptor['sha1'], destination)

      took = Time.now.utc - start

      logger.debug 'resource_pool.download.complete', took: took, destination: destination
    else
      logger.warn 'resource_pool.sync.failed', unknown_resource: descriptor, destination: destination
      raise ArgumentError.new("Can not copy bits we do not have #{descriptor}")
    end
  end

  private

  def logger
    @logger ||= Steno.logger('cc.resource_pool')
  end

  def resource_known?(descriptor)
    size = descriptor['size']
    sha1 = descriptor['sha1']
    if size_allowed?(size) && valid_sha?(sha1)
      blobstore.exists?(sha1)
    end
  rescue => e
    logger.error('blobstore error: ' + e.to_s)
    raise e
  end

  def resource_allowed?(path)
    stat = File.stat(path)
    File.file?(path) && !stat.symlink? && size_allowed?(stat.size)
  end

  def size_allowed?(size)
    size && size > minimum_size && size < maximum_size
  end

  def valid_sha?(sha1)
    sha1 && sha1.to_s.length == VALID_SHA_LENGTH
  end
end
