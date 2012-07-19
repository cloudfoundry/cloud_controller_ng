# Copyright (c) 2009-2012 VMware, Inc.
#
# This is pretty much a direct copy from the legacy cc.
#
# A "resource" is typically represented as a Hash with two attributes:
# :size (bytes)
# :sha1 (string)
# If there are other attributes, such as in legacy calls to "match_resources",
# they will be ignored and preserved.
#
# See config/initializers/resource_pool.rb for where this is initialized
# in production mode.
# See spec/spec_helper.rb for the test initialization.
#
# TODO - Implement "Blob Store" subclass.
class VCAP::CloudController::ResourcePool
  class << self
    attr_accessor :minimum_size, :maximum_size

    def configure(config = {})
      # the old legacy code had a minimum requirement here that it set to 0.
      # but.. since all files bounce through the resource pool, that doesn't
      # make much sense.
      opts = config[:resource_pool] || {}
      @maximum_size = opts[:maximum_size] || 512 * 1024 * 1024 # MB
    end

    def match_resources(descriptors)
      descriptors.select { |h| resource_known?(h) }
    end

    def resource_known?(descriptor)
      raise NotImplementedError, "Implemented in subclasses. See filesystem.rb for example."
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

    # Reads +path+ from the local disk and adds it to the pool, if needed.
    def add_path(path)
      raise NotImplementedError, "Implement in each subclass"
    end

    def copy(descriptor, destination)
      if resource_known?(descriptor)
        overwrite_destination_with!(descriptor, destination)
      else
        raise ArgumentError, "Can not copy bits we do not have"
      end
    end

    private

    def logger
      @logger ||= VCAP::Logging.logger("cc.resource_pool")
    end

    def resource_allowed?(path)
      stat = File.stat(path)
      File.file?(path) && !stat.symlink? && stat.size < maximum_size
    end

    # Called after we sanity-check the input.
    # Create a new path on disk containing the resource described by +descriptor+
    def overwrite_destination_with!(descriptor, destination)
      raise NotImplementedError, "Implemented in subclasses. See filesystem_pool for example."
    end
  end
end
