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
        opts = config[:packages]
        @tmp_dir = config[:directories] ? config[:directories][:tmpdir] : nil
        @app_package_directory_key = opts[:app_package_directory_key] || "cc-app-packages"
        @connection_config = opts[:fog_connection]
        @max_droplet_size = opts[:max_droplet_size] || 512 * 1024 * 1024
        @directory = nil
      end

      # Collects the necessary files and returns the sha1 of the resulting
      # app package.
      def to_zip(guid, resources, uploaded_file)
        validate_package_size(uploaded_file, resources)

        tmpdir = Dir.mktmpdir("app", @tmp_dir)
        unpacked_path = unpack_upload(uploaded_file)
        synchronize_pool_with(unpacked_path, resources)

        repacked_path = AppPackage.repack_app_in(unpacked_path, tmpdir)

        # Do the sha1 before the mv, because the mv might be to a slower store
        sha1 = Digest::SHA1.file(repacked_path).hexdigest

        File.open(repacked_path) do |file|
          package_dir.files.create(
            :key => key_from_guid(guid),
            :body => file,
            :public => local?
          )
        end

        sha1
      ensure
        FileUtils.rm_rf(tmpdir) if tmpdir
        FileUtils.rm_rf(unpacked_path) if unpacked_path
        FileUtils.rm_rf(File.dirname(repacked_path)) if repacked_path
      end

      def delete_package(guid)
        key = key_from_guid(guid)
        package_dir.files.destroy(key)
      end

      def package_exists?(guid)
        key = key_from_guid(guid)
        !package_dir.files.head(key).nil?
      end

      # Return app uri for path for a given app's guid.
      #
      # The url is valid for 1 hour when using aws.
      # TODO: The expiration should be configurable.
      def package_uri(guid)
        key = key_from_guid(guid)
        f = package_dir.files.head(key)
        return nil unless f

        # unfortunately fog doesn't have a unified interface for non-public
        # urls
        if local?
          f.public_url
        else
          f.url(Time.now + 3600)
        end
      end

      def package_local_path(guid)
        raise ArgumentError unless local?
        key = key_from_guid(guid)
        f = package_dir.files.head(key)
        return nil unless f
        # Yes, this is bad.  But, we really need a handle to the actual path in
        # order to serve the file using send_file since send_file only takes a
        # path as an argument
        f.send(:path)
      end

      # Unzip the uploaded file
      def unpack_upload(uploaded_file)
        working_dir = Dir.mktmpdir("unpacked", @tmp_dir)
        return working_dir unless uploaded_file

        if uploaded_file
          cmd = "unzip -q -d #{working_dir} #{uploaded_file.path}"
          run("unzipping application", cmd)
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
        sizes = ResourcePool.instance.resource_sizes(resources)
        total_size += sizes.reduce(0) {|accum, cur| accum + cur["size"] }
        validate_size(total_size)
      end

      # Extract the file size of the unzipped app
      def unzipped_size(uploaded_file)
        cmd = "unzip -l #{uploaded_file.path}"
        output = run("listing application archive", cmd)

        matches = output.lines.to_a.last.match(/^\s*(\d+)\s+(\d+) file/)
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
        ResourcePool.instance.add_directory(working_dir)
        resource_descriptors.each do |descriptor|
          create_dir_skeleton(working_dir, descriptor["fn"])
          path = resolve_path(working_dir, descriptor["fn"])
          ResourcePool.instance.copy(descriptor, path)
        end
      rescue => e
        logger.error "failed synchronizing resource pool with '#{working_dir}' #{e}"
        raise Errors::AppPackageInvalid.new("failed synchronizing resource pool #{e}")
      end

      # Repacks a directory into a compressed file.
      def repack_app_in(dir, tmpdir)
        target_path = File.join(tmpdir, 'app.zip')
        files = File.exists?(dir) ? Dir.entries(dir) - %w[. ..] : []
        cmd = "zip -q -y -r #{target_path} #{files.join(" ")}"
        run("repacking application", cmd, :chdir => dir)
        target_path
      end

      # Runs a command, returns the output
      def run(msg, cmd, opts = {})
        logger.debug "run '#{cmd}'"
        child = POSIX::Spawn::Child.new(cmd, opts)
        if child.status.exitstatus != 0
          logger.error "command failed: '#{cmd}'"
          logger.error "failed command out: '#{child.out}', err: '#{child.err}'"
          raise Errors::AppPackageInvalid.new("failed #{msg}")
        end
        child.out
      end

      def logger
        @logger ||= Steno.logger("cc.ap")
      end

      def connection
        opts = @connection_config
        opts = opts.merge(:endpoint => "") if local?
        Fog::Storage.new(opts)
      end

      def package_dir
        @directory ||= connection.directories.create(
          :key    => @app_package_directory_key,
          :public => false,
        )
      end

      def key_from_guid(guid)
        guid = guid.to_s.downcase
        File.join(guid[0..1], guid[2..3], guid)
      end

      def local?
        @connection_config[:provider].downcase == "local"
      end

      attr_accessor :max_droplet_size
    end
  end
end
