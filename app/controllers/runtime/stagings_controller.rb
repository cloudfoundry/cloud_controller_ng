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
require "cloud_controller/blobstore/blobstore"

module VCAP::CloudController
  class StagingsController < RestController::Base
    include VCAP::Errors

    STAGING_PATH = "/staging"

    DROPLET_PATH = "#{STAGING_PATH}/droplets"
    BUILDPACK_CACHE_PATH = "#{STAGING_PATH}/buildpack_cache"

    # Endpoint does its own basic auth
    allow_unauthenticated_access

    authenticate_basic_auth("#{STAGING_PATH}/*") do
      [@config[:staging][:auth][:user], @config[:staging][:auth][:password]]
    end

    attr_reader :config

    class << self
      attr_reader :blobstore, :buildpack_cache_blobstore

      def configure(config)
        @config = config

        options = config[:droplets]
        cdn = options[:cdn] ? Cdn.make(options[:cdn][:uri]) : nil

        @blobstore = Blobstore.new(
          options[:fog_connection],
          options[:droplet_directory_key] || "cc-droplets",
          cdn)

        @buildpack_cache_blobstore = Blobstore.new(
          options[:fog_connection],
          options[:droplet_directory_key] || "cc-droplets",
          cdn,
          "buildpack_cache"
        )
      end

      def store_droplet(app, path)
        CloudController::BlobstoreDroplet.new(app, blobstore).save(path)
      end

      def store_buildpack_cache(app, path)
        buildpack_cache_blobstore.cp_to_blobstore(
          path,
          app.guid
        )
      end

      private
      def logger
        @logger ||= Steno.logger("cc.legacy_staging")
      end
    end

    def download_app(guid)
      package_blobstore = CloudController::DependencyLocator.instance.package_blobstore
      raise InvalidRequest unless package_blobstore.local?

      app = App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?

      file = package_blobstore.file(guid)
      package_path = file.send(:path) if file
      logger.debug "guid: #{guid} package_path: #{package_path}"

      unless package_path
        logger.error "could not find package for #{guid}"
        raise AppPackageNotFound.new(guid)
      end

      if config[:nginx][:use_nginx]
        url = package_blobstore.download_uri(guid)
        logger.debug "nginx redirect #{url}"
        [200, { "X-Accel-Redirect" => url }, ""]
      else
        logger.debug "send_file #{package_path}"
        send_file package_path
      end
    end

    def upload_droplet(guid)
      app = App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?
      raise StagingError.new("malformed droplet upload request for #{app.guid}") unless upload_path

      #TODO: put in background job
      start = Time.now
      CloudController::BlobstoreDroplet.new(app, self.class.blobstore).save(upload_path)
      logger.debug "droplet.uploaded", took: Time.now - start
      app.save
      logger.debug "droplet.saved", :sha => app.droplet_hash, :app_guid => app.guid

      HTTP::OK
    ensure
      FileUtils.rm_f(upload_path) if upload_path
    end

    def upload_buildpack_cache(guid)
      app = App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?
      raise StagingError.new("malformed buildpack cache upload request for #{app.guid}") unless upload_path

      # TODO: put in background job
      self.class.store_buildpack_cache(app, upload_path)

      HTTP::OK
    ensure
      FileUtils.rm_f(upload_path) if upload_path
    end

    def download_droplet(guid)
      app = App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?

      droplet = CloudController::BlobstoreDroplet.new(app, StagingsController.blobstore)
      droplet_path = droplet.local_path
      droplet_url = droplet.download_url

      download(app, droplet_path, droplet_url, "droplet")
    end

    def download_buildpack_cache(guid)
      app = App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?

      file = StagingsController.buildpack_cache_blobstore.file(app.guid)
      buildpack_cache_path = file.send(:path) if file
      buildpack_cache_url =  StagingsController.buildpack_cache_blobstore.download_uri(app.guid)
      download(app, buildpack_cache_path, buildpack_cache_url, "buildpack cache")
    end

    private

    def download(app, blob_path, url, name)
      raise InvalidRequest unless self.class.blobstore.local?

      logger.debug "guid: #{app.guid} #{name} #{blob_path} #{url}"

      unless blob_path
        Loggregator.emit_error(app.guid, "Did not find #{name} for app with guid: #{app.guid}")
        logger.error "could not find #{name} for #{app.guid}"
        raise StagingError.new("#{name} not found for #{app.guid}")
      end

      if config[:nginx][:use_nginx]
        logger.debug "nginx redirect #{url}"
        [200, { "X-Accel-Redirect" => url }, ""]
      else
        logger.debug "send_file #{blob_path}"
        send_file blob_path
      end
    end

    def upload(app, type)
      tag = (type == :buildpack_cache) ? "buildpack_cache" : "staged_droplet"

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

    def tmpdir
      (config[:directories] && config[:directories][:tmpdir]) || Dir.tmpdir
    end

    get "/staging/apps/:guid", :download_app

    # Make sure that nginx upload path rules do not apply to download paths!
    post "#{DROPLET_PATH}/:guid/upload", :upload_droplet
    get "#{DROPLET_PATH}/:guid/download", :download_droplet

    post "#{BUILDPACK_CACHE_PATH}/:guid/upload", :upload_buildpack_cache
    get "#{BUILDPACK_CACHE_PATH}/:guid/download", :download_buildpack_cache
  end
end
