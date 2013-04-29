# Copyright (c) 2009-2012 VMware, Inc.

# All the storing and deleting of droplets was pushed into this class as it is
# a mix of legacy cc and fog related work.  This is because this class is
# responsible for handing out the urls to the droplets, which now gets
# delegated to fog. There is also substantial overlap in code and functionality
# with AppPackage.
#
# As part of the refactor to use the Fog gem, this ended up being done by
# dropping Fog in place directly.  However, now that there is more going on at
# the storage layer than FileUtils.mv, this should get refactored.

module VCAP::CloudController
  class Staging < RestController::Base
    include VCAP::Errors

    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    APP_PATH = "/staging/apps"
    DROPLET_PATH = "/staging/droplets"
    BUILDPACK_CACHE_PATH = "/staging/buildpack_cache"

    class DropletUploadHandle
      attr_accessor :guid, :upload_path, :buildpack_cache_upload_path

      def initialize(guid)
        @guid = guid
        @upload_path = nil
      end
    end

    attr_reader :config

    class << self
      def configure(config)
        @config = config

        opts = config[:droplets]
        @droplet_directory_key = opts[:droplet_directory_key] || "cc-droplets"
        @connection_config = opts[:fog_connection]
        @directory = nil
      end

      def app_uri(guid)
        if AppPackage.local?
          staging_uri("#{APP_PATH}/#{guid}")
        else
          AppPackage.package_uri(guid)
        end
      end

      def droplet_upload_uri(guid)
        upload_uri(guid, :droplet)
      end

      def buildpack_cache_upload_uri(guid)
        upload_uri(guid, :buildpack_cache)
      end

      def droplet_download_uri(guid)
        if local?
          staging_uri("#{DROPLET_PATH}/#{guid}")
        else
          droplet_uri(guid)
        end
      end

      def create_handle(guid)
        handle = DropletUploadHandle.new(guid)
        mutex.synchronize { upload_handles[handle.guid] = handle }
        handle
      end

      def destroy_handle(handle)
        return unless handle
        mutex.synchronize do
          files_to_delete = [handle.upload_path, handle.buildpack_cache_upload_path]
          files_to_delete.each do |file|
            File.delete(file) if file && File.exists?(file)
          end
          upload_handles.delete(handle.guid)
        end
      end

      def lookup_handle(guid)
        mutex.synchronize do
          return upload_handles[guid]
        end
      end

      def store_droplet(guid, path)
        store_package(guid, path, :droplet)
      end

      def store_buildpack_cache(guid, path)
        store_package(guid, path, :buildpack_cache)
      end

      def delete_droplet(guid)
        key = key_from_guid(guid, :droplet)
        droplet_dir.files.destroy(key)
      rescue Errno::ENOTEMPTY => e
        logger.warn("Failed to delete droplet: #{e}\n#{e.backtrace}")
        true
      end

      def droplet_exists?(guid)
        key = key_from_guid(guid, :droplet)
        !droplet_dir.files.head(key).nil?
      end

      def local?
        @connection_config[:provider].downcase == "local"
      end

      def buildpack_cache_download_uri(guid)
        if AppPackage.local?
          staging_uri("#{BUILDPACK_CACHE_PATH}/#{guid}")
        else
          package_uri(guid, :buildpack_cache)
        end
      end

      def droplet_local_path(guid)
        local_path(guid, :droplet)
      end

      def buildpack_cache_local_path(guid)
        local_path(guid, :buildpack_cache)
      end

      # Return droplet uri for path for a given app's guid.
      #
      # The url is valid for 1 hour when using aws.
      # TODO: The expiration should be configurable.
      def droplet_uri(guid)
        package_uri(guid, :droplet)
      end

      def buildpack_cache_uri(guid)
        package_uri(guid, :buildpack_cache)
      end

      private

      def store_package(guid, path, type)
        File.open(path) do |file|
          droplet_dir.files.create(
            :key => key_from_guid(guid, type),
            :body => file,
            :public => local?
          )
        end
      end

      def upload_uri(guid, type)
        if type == :buildpack_cache
          staging_uri("#{BUILDPACK_CACHE_PATH}/#{guid}")
        else
          staging_uri("#{DROPLET_PATH}/#{guid}")
        end
      end

      def package_uri(guid, type)
        key = key_from_guid(guid, type)
        f = droplet_dir.files.head(key)
        return nil unless f

        # unfortunately fog doesn't have a unified interface for non-public
        # urls
        if local?
          f.public_url
        else
          f.url(Time.now + 3600)
        end
      end

      def staging_uri(path)
        URI::HTTP.build(
          :host     => @config[:bind_address],
          :port     => @config[:port],
          :userinfo => [@config[:staging][:auth][:user], @config[:staging][:auth][:password]],
          :path     => path
        ).to_s
      end

      def upload_handles
        @upload_handles ||= {}
      end

      MUTEX = Mutex.new
      def mutex
        MUTEX
      end

      def logger
        @logger ||= Steno.logger("cc.legacy_staging")
      end

      def connection
        opts = @connection_config
        opts = opts.merge(:endpoint => "") if local?
        Fog::Storage.new(opts)
      end

      def droplet_dir
        @directory ||= connection.directories.create(
          :key    => @droplet_directory_key,
          :public => false,
        )
      end

      def key_from_guid(guid, type)
        guid = guid.to_s.downcase
        if type == :buildpack_cache
          File.join("buildpack_cache", guid[0..1], guid[2..3], guid)
        else
          File.join(guid[0..1], guid[2..3], guid)
        end
      end

      def local_path(guid, type)
        raise ArgumentError unless local?
        key = key_from_guid(guid, type)
        f = droplet_dir.files.head(key)
        return nil unless f
        # Yes, this is bad.  But, we really need a handle to the actual path in
        # order to serve the file using send_file since send_file only takes a
        # path as an argument
        f.send(:path)
      end
    end

    # Handles an app download from a stager
    def download_app(guid)
      raise InvalidRequest unless AppPackage.local?

      app = Models::App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?

      package_path = AppPackage.package_local_path(guid)
      logger.debug "guid: #{guid} package_path: #{package_path}"

      unless package_path
        logger.error "could not find package for #{guid}"
        raise AppPackageNotFound.new(guid)
      end

      if config[:nginx][:use_nginx]
        url = AppPackage.package_uri(guid)
        logger.debug "nginx redirect #{url}"
        return [200, { "X-Accel-Redirect" => url }, ""]
      else
        logger.debug "send_file #{package_path}"
        return send_file package_path
      end
    end

    # Handles a droplet upload from a stager
    def upload_droplet(guid)
      upload(guid, :droplet)
    end

    # Handles a buildpack cache upload from a stager
    def upload_buildpack_cache(guid)
      upload(guid, :buildpack_cache)
    end

    def download_droplet(guid)
      droplet_path = Staging.droplet_local_path(guid)
      droplet_url = Staging.droplet_uri(guid)
      download(guid, droplet_path, droplet_url)
    end

    def download_buildpack_cache(guid)
      buildpack_cache_path = Staging.buildpack_cache_local_path(guid)
      buildpack_cache_url = Staging.buildpack_cache_uri(guid)
      download(guid, buildpack_cache_path, buildpack_cache_url)
    end

    private

    def download(guid, droplet_path, url)
      raise InvalidRequest unless Staging.local?

      app = Models::App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?

      logger.debug "guid: #{guid} droplet_path #{droplet_path}"

      unless droplet_path
        logger.error "could not find droplet for #{guid}"
        raise StagingError.new("droplet not found for #{guid}")
      end

      if config[:nginx][:use_nginx]
        logger.debug "nginx redirect #{url}"
        return [200, { "X-Accel-Redirect" => url }, ""]
      else
        logger.debug "send_file #{droplet_path}"
        return send_file droplet_path
      end
    end

    def upload(guid, type)
      tag = (type == :buildpack_cache) ? "buildpack_cache" : "staged_droplet"
      app = Models::App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?

      handle = self.class.lookup_handle(guid)
      raise StagingError.new("staging not in progress for #{guid}") unless handle
      raise StagingError.new("malformed droplet upload request for #{guid}") unless upload_file

      upload_path = upload_file.path
      final_path = save_path(guid, tag)
      logger.debug "renaming #{tag} from '#{upload_path}' to '#{final_path}'"

      begin
        File.rename(upload_path, final_path)
      rescue => e
        raise StagingError.new("failed renaming #{tag} droplet: #{e}")
      end

      if type == :buildpack_cache
        handle.buildpack_cache_upload_path = final_path
      else
        handle.upload_path = final_path
      end

      logger.debug "uploaded #{tag} for #{guid} to #{final_path}"

      HTTP::OK
    end

    # returns an object that responds to #path pointing to the uploaded file
    # @return [#path]
    def upload_file
      @upload_file ||=
        if get_from_hash_tree(config, :nginx, :use_nginx)
          Struct.new(:path).new(params["droplet_path"])
        else
          get_from_hash_tree(params, "upload", "droplet", :tempfile)
        end
    end

    def get_from_hash_tree(hash, *path)
      path.reduce(hash) do |here, seg|
        return unless here && here.is_a?(Hash)
        here[seg]
      end
    end

    def save_path(guid, tag)
      File.join(tmpdir, "#{tag}_upload_#{guid}.tgz")
    end

    def tmpdir
      (config[:directories] && config[:directories][:tmpdir]) || Dir.tmpdir
    end

    # TODO: put this back to all of staging once we change the auth scheme
    # (and add a test for /staging/droplets with bad auth)
    controller.before "#{APP_PATH}/*" do
      auth =  Rack::Auth::Basic::Request.new(env)
      unless (auth.provided? && auth.basic? && auth.credentials &&
              auth.credentials == [@config[:staging][:auth][:user],
                                   @config[:staging][:auth][:password]])
        raise NotAuthorized
      end
    end

    get  "/staging/apps/:guid", :download_app
    post "#{DROPLET_PATH}/:guid", :upload_droplet
    get  "#{DROPLET_PATH}/:guid", :download_droplet

    post "#{BUILDPACK_CACHE_PATH}/:guid", :upload_buildpack_cache
    get "#{BUILDPACK_CACHE_PATH}/:guid", :download_buildpack_cache
  end
end
