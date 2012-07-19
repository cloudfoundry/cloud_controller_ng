# Copyright (c) 2009-2012 VMware, Inc.
#
# This is pretty much a direct port from the legacy cc, with all the same
# parameters so that legacy and ccng can share the same resource pool.

class VCAP::CloudController::FilesystemPool < VCAP::CloudController::ResourcePool
  # These used to be configurable in the legacy cc, but, you really can't
  # change them once a resource pool is in place.  That is not safe.  Given
  # that we never configured these, lets just make them constants.  We're going
  # to move away from file based resource pool to the vblob soon anyway.
  LEVELS = 2
  MODULOS = [269, 251]

  class << self
    attr_reader :directory, :levels, :modulos

    def configure(config = {})
      super
      dir_config = config[:directories] || {}
      @directory = dir_config[:resources] || Dir.mktmpdir.to_s
      @levels = LEVELS
      @modulos = MODULOS
    end

    def resource_known?(descriptor)
      resource_path = path_from_sha1(descriptor[:sha1])
      if File.exists?(resource_path)
        File.size(resource_path) == descriptor[:size].to_i
      else
        logger.error "resource size mismatch #{resource_path}"
        false
      end
    end

    def add_path(path)
      file = File.stat(path)
      sha1 = Digest::SHA1.file(path).hexdigest
      resource_path = path_from_sha1(sha1)
      return if File.exists?(resource_path)
      FileUtils.mkdir_p File.dirname(resource_path)
      FileUtils.cp(path, resource_path)
      true
    end

    def resource_sizes(resources)
      sizes = []
      resources.each do |descriptor|
        resource_path = path_from_sha1(descriptor[:sha1])
        if File.exists?(resource_path)
          entry = descriptor.dup
          entry[:size] = File.size(resource_path)
          sizes << entry
        end
      end
      sizes
    end

    private

    def overwrite_destination_with!(descriptor, destination)
      FileUtils.mkdir_p File.dirname(destination)
      resource_path = path_from_sha1(descriptor[:sha1])
      FileUtils.cp(resource_path, destination)
    end

    def path_from_sha1(sha1)
      sha1 = sha1.to_s.downcase
      as_integer = Integer("0x#{sha1}")
      dirs = []
      levels.times do |i|
        dirs << as_integer.modulo(modulos[i]).to_s
      end
      dir = File.join(directory, *dirs)
      File.join(dir, sha1)
    end
  end
end
