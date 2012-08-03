# Copyright (c) 2009-2012 VMware, Inc.
#
# This is a port of the legacy AppPackage but modified for user with threads
# instead of fibers.

require "posix/spawn"

module VCAP::CloudController
  module AppPackage
    class << self
      # Configure the AppPackage
      def configure(config = {})
        @config = config
        @max_droplet_size = config[:max_droplet_size] || 512 * 1024 * 1024
        @resource_pool = FilesystemPool
      end

      # Collects the necessary files and returns the sha1 of the resulting
      # app package.
      def to_zip(guid, uploaded_file, resources)
        validate_package_size(uploaded_file, resources)

        tmpdir = Dir.mktmpdir
        unpacked_path = unpack_upload(uploaded_file)
        synchronize_pool_with(unpacked_path, resources)

        repacked_path = AppPackage.repack_app_in(unpacked_path, tmpdir)

        # Do the sha1 before the mv, because the mv might be to a slower store
        sha1 = Digest::SHA1.file(repacked_path).hexdigest
        FileUtils.mv(repacked_path, package_path(guid))
        sha1
      ensure
        FileUtils.rm_rf(tmpdir) if tmpdir
        FileUtils.rm_rf(unpacked_path) if unpacked_path
        FileUtils.rm_rf(File.dirname(repacked_path)) if repacked_path
      end

      # Return the package directory.
      #
      # Makes the directory on first use.
      def package_dir
        unless @package_dir
          # TODO: remove this tmpdir.  It is for use when running under vcap
          # for development
          @package_dir = @config[:directories] && @config[:directories][:droplets]
          @package_dir ||= Dir.mktmpdir
          FileUtils.mkdir_p(@package_dir) unless File.directory?(@package_dir)
        end
        @package_dir
      end

      # Return app package path for a given app's guid.
      def package_path(guid)
        File.join(package_dir, "app_#{guid}")
      end

      # Unzip the uploaded file
      def unpack_upload(uploaded_file)
        working_dir = Dir.mktmpdir
        return working_dir unless uploaded_file

        if uploaded_file
          cmd = "unzip -q -d #{working_dir} #{uploaded_file.path}"
          (rc, out, err) = run("unzipping application", cmd)
        end
        working_dir
      end

      # Verifies that the recreated droplet size is less than the
      # maximum allowed by the config.
      def validate_package_size(uploaded_file, resources)
        logger.debug "uploaded_file: #{uploaded_file}"

        # When the entire set of files that make up the application is already
        # in the resource pool, the client may not send us any additional contents
        # i.e. the payload is empty.
        return unless uploaded_file

        total_size = unzipped_size(uploaded_file)

        # Avoid stat'ing files in the resource pool if possible
        validate_size(total_size)

        # Ugh, this stat's all the files that would need to be copied
        # from the resource pool. Consider caching sizes in resource pool?
        sizes = resource_pool.resource_sizes(resources)
        total_size += sizes.reduce(0) {|accum, cur| accum + cur["size"] }
        validate_size(total_size)
      end

      # Extract the file size of the unzipped app
      def unzipped_size(uploaded_file)
        cmd = "unzip -l #{uploaded_file.path}"
        (rc, out, err) = run("listing application archive", cmd)

        matches = out.lines.to_a.last.match(/^\s*(\d+)\s+(\d+) file/)
        unless matches
          msg = "failed parsing application archive listing"
          raise Errors::AppPackageInvalid.new(msg)
        end

        Integer(matches[1])
      end

      # Validates a package size against the max droplet size
      def validate_size(size)
        if size > max_droplet_size
          limit_str = VCAP.pp_bytesize(max_droplet_size)
          size_str = VCAP.pp_bytesize(size)
          msg = "Application size #{size_str} exceeds limit #{limit_str}"
          raise Errors::AppPackageInvalid.new(msg)
        end
      end

      # Creates the directory structure leading up to the resource specified by
      # _resource_path_, relative to _working_dir_.
      #
      # @param [String] working_dir
      #
      # @param [String] resource_path Relative path for the resource in question.
      def create_dir_skeleton(working_dir, resource_path)
        real_path = File.expand_path(resource_path, working_dir)

        if !real_path.start_with?(working_dir)
          msg = "'#{resource_path}' points outside app package"
          raise Errors::AppPackageInvalid.new(msg)
        end

        FileUtils.mkdir_p(File.dirname(real_path))
      end

      # enforce property that any file in resource list must be located in the
      # apps directory e.g. '../../foo' or a symlink pointing outside working_dir
      # should raise an exception.
      def resolve_path(working_dir, tainted_path)
        expanded_dir  = File.realdirpath(working_dir)
        expanded_path = File.realdirpath(tainted_path, expanded_dir)
        pattern = "#{expanded_dir}/*"
        unless File.fnmatch?(pattern, expanded_path)
          msg = "resource path sanity check failed #{pattern}:#{expanded_path}"
          raise Errors::AppPackageInvalid.new(msg)
        end
        expanded_path
      end

      # Do resource pool synch
      def synchronize_pool_with(working_dir, resource_descriptors)
        resource_pool.add_directory(working_dir)
        resource_descriptors.each do |descriptor|
          create_dir_skeleton(working_dir, descriptor["fn"])
          path = resolve_path(working_dir, descriptor["fn"])
          resource_pool.copy(descriptor, path)
        end
      rescue => e
        logger.error "failed synchronizing resource pool with '#{working_dir}' #{e}"
        raise Errors::AppPackageInvalid.new("failed synchronizing resource pool")
      end

      # Repacks a directory into a compressed file.
      def repack_app_in(dir, tmpdir)
        target_path = File.join(tmpdir, 'app.zip')
        cmd = "zip -q -y -r #{target_path} *"
        (rc, out, err) = run("repacking application", cmd, :chdir => dir)
        target_path
      end

      # Runs a command, returns the status, stdout, and stderr
      def run(msg, cmd, opts = {})
        logger.debug "run '#{cmd}'"
        child = POSIX::Spawn::Child.new(cmd, opts)
        if child.status.exitstatus != 0
          logger.error "'#{cmd}' failed out: '#{child.out}' err: '#{child.err}'"
          raise Errors::AppPackageInvalid.new("failed #{msg}")
        end
        [child.status.exitstatus, child.out, child.err]
      end

      def logger
        @logger ||= Steno.logger("cc.ap")
      end

      attr_accessor :max_droplet_size, :resource_pool, :droplets_dir
    end
  end
end
