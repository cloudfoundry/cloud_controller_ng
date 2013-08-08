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

require "cloudfront-signer"
require "cloud_controller/blob_store"

module VCAP::CloudController
  class StagingsController < RestController::Base
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
      attr_reader :blob_store

      def configure(config)
        @config = config

        options = config[:droplets]
        @blob_store = VCAP::CloudController::BlobStore.new(options[:fog_connection], options[:droplet_directory_key] || "cc-droplets")
        @cdn = options[:cdn]
      end

      def app_uri(app)
        if AppPackage.blob_store.local?
          staging_uri("#{APP_PATH}/#{app.guid}")
        else
          AppPackage.package_uri(app.guid)
        end
      end

      def droplet_upload_uri(app)
        upload_uri(app, :droplet)
      end

      def droplet_download_uri(app)
        if blob_store.local?
          staging_uri("#{DROPLET_PATH}/#{app.guid}/download")
        else
          droplet_uri(app)
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

      def store_droplet(app, path)
        store_package(app, path, :droplet)
      end

      def store_buildpack_cache(app, path)
        store_package(app, path, :buildpack_cache)
      end

      def delete_droplet(app)
        file = app_droplet(app)
        file.destroy if file
      rescue Errno::ENOTEMPTY => e
        logger.warn("Failed to delete droplet: #{e}\n#{e.backtrace}")
        true  
      rescue StandardError => e
        # NotFound errors do not share a common superclass so we have to determine it by name
        # A github issue for fog will be created.
        if e.class.name.split('::').last.eql?("NotFound")
          logger.warn("Failed to delete droplet: #{e}\n#{e.backtrace}")
          true
        else
          # None-NotFound errors will be raised again
          raise e
        end      
      end

      def droplet_exists?(app)
        !!app_droplet(app)
      end

      def buildpack_cache_upload_uri(app)
        upload_uri(app, :buildpack_cache)
      end

      def buildpack_cache_download_uri(app)
        if AppPackage.blob_store.local?
          staging_uri("#{BUILDPACK_CACHE_PATH}/#{app.guid}/download")
        else
          package_uri(app, :buildpack_cache)
        end
      end

      def droplet_local_path(app)
        file = app_droplet(app)
        file.send(:path) if file
      end

      def buildpack_cache_local_path(app)
        file = app_buildpack_cache(app)
        file.send(:path) if file
      end

      # Return droplet uri for path for a given app's guid.
      #
      # The url is valid for 1 hour when using aws.
      # TODO: The expiration should be configurable.
      def droplet_uri(app)
        package_uri(app, :droplet)
      end

      def buildpack_cache_uri(app)
        package_uri(app, :buildpack_cache)
      end

      private

      def store_package(app, path, type)
        File.open(path) do |file|
          blob_store.files.create(
            :key => key_from_app(app, type),
            :body => file,
            :public => blob_store.local?
          )
        end
      end

      def upload_uri(app, type)
        prefix = type == :buildpack_cache ? BUILDPACK_CACHE_PATH : DROPLET_PATH
        staging_uri("#{prefix}/#{app.guid}/upload")
      end

      def package_uri(app, type)
        if type == :buildpack_cache
          f = app_buildpack_cache(app)
        elsif type == :droplet
          f = app_droplet(app)
        else
          raise "unknown type #{type}"
        end

        return nil unless f

        # unfortunately fog doesn't have a unified interface for non-public
        # urls
        if blob_store.local?
          f.public_url
        elsif @cdn && @cdn[:uri]
          uri = "#{@cdn[:uri]}/#{f.key}"
          AWS::CF::Signer.is_configured? ? AWS::CF::Signer.sign_url(uri) : uri
        elsif f.respond_to?(:url)
          f.url(Time.now + 3600)
        else
          f.public_url
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

      def app_droplet(app)
        return unless app.staged?

        key = key_from_app(app, :droplet)
        old_key = key_from_guid(app.guid, :droplet)
        blob_store.files.head(key) || blob_store.files.head(old_key)
      end

      def app_buildpack_cache(app)
        key = key_from_guid(app.guid, :buildpack_cache)
        blob_store.files.head(key)
      end

      def key_from_app(app, type)
        if type == :droplet
          File.join(key_from_guid(app.guid, type), app.droplet_hash)
        else
          key_from_guid(app.guid, type)
        end
      end

      def key_from_guid(guid, type)
        guid = guid.to_s.downcase

        if type == :buildpack_cache
          File.join("buildpack_cache", guid[0..1], guid[2..3], guid)
        else
          File.join(guid[0..1], guid[2..3], guid)
        end
      end
    end

    def download_app(guid)
      raise InvalidRequest unless AppPackage.blob_store.local?

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
        [200, { "X-Accel-Redirect" => url }, ""]
      else
        logger.debug "send_file #{package_path}"
        send_file package_path
      end
    end

    def upload_droplet(guid)
      app = Models::App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?

      upload(app, :droplet)
    end

    def upload_buildpack_cache(guid)
      app = Models::App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?

      upload(app, :buildpack_cache)
    end

    def download_droplet(guid)
      app = Models::App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?

      droplet_path = StagingsController.droplet_local_path(app)
      droplet_url = StagingsController.droplet_uri(app)
      download(app, droplet_path, droplet_url)
    end

    def download_buildpack_cache(guid)
      app = Models::App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?

      buildpack_cache_path = StagingsController.buildpack_cache_local_path(app)
      buildpack_cache_url = StagingsController.buildpack_cache_uri(app)
      download(app, buildpack_cache_path, buildpack_cache_url)
    end

    private

    def download(app, droplet_path, url)
      raise InvalidRequest unless self.class.blob_store.local?

      logger.debug "guid: #{app.guid} droplet_path #{droplet_path}"

      unless droplet_path
        logger.error "could not find droplet for #{app.guid}"
        raise StagingError.new("droplet not found for #{app.guid}")
      end

      if config[:nginx][:use_nginx]
        logger.debug "nginx redirect #{url}"
        [200, { "X-Accel-Redirect" => url }, ""]
      else
        logger.debug "send_file #{droplet_path}"
        send_file droplet_path
      end
    end

    def upload(app, type)
      tag = (type == :buildpack_cache) ? "buildpack_cache" : "staged_droplet"

      handle = self.class.lookup_handle(app.guid)
      raise StagingError.new("staging not in progress for #{app.guid}") unless handle
      raise StagingError.new("malformed droplet upload request for #{app.guid}") unless upload_path

      final_path = save_path(app.guid, tag)
      logger.debug "renaming #{tag} from '#{upload_path}' to '#{final_path}'"

      begin
        File.rename(upload_path, final_path)
      rescue => e
        raise StagingError.new("failed renaming #{tag} droplet from #{upload_path} to #{final_path}: #{e.inspect}\n#{e.backtrace.join("\n")}")
      end

      if type == :buildpack_cache
        handle.buildpack_cache_upload_path = final_path
      else
        handle.upload_path = final_path
      end

      logger.debug "uploaded #{tag} for #{app.guid} to #{final_path}"

      HTTP::OK
    end

    def upload_path
      @upload_path ||=
        if get_from_hash_tree(config, :nginx, :use_nginx)
          params["droplet_path"]
        elsif (tempfile = get_from_hash_tree(params, "upload", "droplet", :tempfile))
          tempfile.path
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
      unless auth.provided? && auth.basic? &&
              auth.credentials == [@config[:staging][:auth][:user],
                                   @config[:staging][:auth][:password]]
        raise NotAuthorized
      end
    end

    get  "/staging/apps/:guid", :download_app

    # Make sure that nginx upload path rules do not apply to download paths!
    post "#{DROPLET_PATH}/:guid/upload", :upload_droplet
    get  "#{DROPLET_PATH}/:guid/download", :download_droplet

    post "#{BUILDPACK_CACHE_PATH}/:guid/upload", :upload_buildpack_cache
    get "#{BUILDPACK_CACHE_PATH}/:guid/download", :download_buildpack_cache
  end
end
