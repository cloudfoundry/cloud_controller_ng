# Copyright (c) 2009-2012 VMware, Inc.
#
# A "resource" is typically represented as a Hash with two attributes:
# :size (bytes)
# :sha1 (string)
# If there are other attributes, such as in legacy calls to "match_resources",
# they will be ignored and preserved.

require "fog"
require "steno"

class VCAP::CloudController::ResourcePool
  class << self
    attr_accessor :minimum_size, :maximum_size

    def configure(config = {})
      opts = config[:resource_pool] || {}
      @connection_config = opts[:fog_connection]
      @resource_directory_key = opts[:resource_directory_key] || "cc-resources"
      @maximum_size = opts[:maximum_size] || 512 * 1024 * 1024 # MB
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
      return if resource_dir.files.head(sha1)

      File.open(path) do |file|
        resource_dir.files.create(
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
        if head = resource_dir.files.head(key)
          entry = descriptor.dup
          entry["size"] = head.content_length
          sizes << entry
        end
      end
      sizes
    end

    def copy(descriptor, destination)
      if resource_known?(descriptor)
        logger.debug "resource pool sync #{descriptor}"
        overwrite_destination_with!(descriptor, destination)
      else
        logger.warn "resource pool sync error #{descriptor}"
        raise ArgumentError, "Can not copy bits we do not have #{descriptor}"
      end
    end

    private

    def logger
      @logger ||= Steno.logger("cc.resource_pool")
    end

    def resource_known?(descriptor)
      key = key_from_sha1(descriptor["sha1"])
      resource_dir.files.head(key)
    end

    def resource_allowed?(path)
      stat = File.stat(path)
      File.file?(path) && !stat.symlink? && stat.size < maximum_size
    end

    # Called after we sanity-check the input.
    # Create a new path on disk containing the resource described by +descriptor+
    def overwrite_destination_with!(descriptor, destination)
      FileUtils.mkdir_p File.dirname(destination)
      s3_key = key_from_sha1(descriptor["sha1"])
      s3_file = resource_dir.files.get(s3_key)
      File.open(destination, "w") do |file|
        file.write(s3_file.body)
      end
    end

    def connection
      Fog::Storage.new(@connection_config)
    end

    def resource_dir
      @directory ||= connection.directories.create(
        :key    => @resource_directory_key,
        :public => false,
      )
    end

    def key_from_sha1(sha1)
      sha1 = sha1.to_s.downcase
      File.join(sha1[0..1], sha1[2..3], sha1)
    end
  end
end
