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
      [VCAP::CloudController::Config.config[:staging][:auth][:user],
       VCAP::CloudController::Config.config[:staging][:auth][:password]]
    end

    attr_reader :config, :blobstore, :buildpack_cache_blobstore, :package_blobstore

    get "/staging/apps/:guid", :download_app
    def download_app(guid)
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
        [200, {"X-Accel-Redirect" => url}, ""]
      else
        logger.debug "send_file #{package_path}"
        send_file package_path
      end
    end

    post "#{DROPLET_PATH}/:guid/upload", :upload_droplet
    def upload_droplet(guid)
      app = App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?
      raise StagingError.new("malformed droplet upload request for #{app.guid}") unless upload_path

      logger.info "droplet.begin-upload", :app_guid => app.guid

      droplet_upload_job = Jobs::Runtime::DropletUpload.new(upload_path, app.id)

      if async?
        job = Jobs::Enqueuer.new(droplet_upload_job, queue: LocalQueue.new(config)).enqueue()
        external_domain = Array(config[:external_domain]).first
        [HTTP::OK, JobPresenter.new(job, "http://#{external_domain}").to_json]
      else
        droplet_upload_job.perform
        HTTP::OK
      end
    end

    get "#{DROPLET_PATH}/:guid/download", :download_droplet
    def download_droplet(guid)
      app = App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?

      droplet = app.current_droplet
      blob_name = "droplet"
      log_and_raise_missing_blob(app.guid, blob_name) unless droplet
      download(app, droplet.local_path, droplet.download_url, blob_name)
    end

    post "#{BUILDPACK_CACHE_PATH}/:guid/upload", :upload_buildpack_cache
    def upload_buildpack_cache(guid)
      app = App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?
      raise StagingError.new("malformed buildpack cache upload request for #{app.guid}") unless upload_path

      blobstore_upload = Jobs::Runtime::BlobstoreUpload.new(upload_path, app.guid, :buildpack_cache_blobstore)
      Jobs::Enqueuer.new(blobstore_upload, queue: LocalQueue.new(config)).enqueue()
      HTTP::OK
    end

    get "#{BUILDPACK_CACHE_PATH}/:guid/download", :download_buildpack_cache
    def download_buildpack_cache(guid)
      app = App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?

      file = buildpack_cache_blobstore.file(app.guid)
      buildpack_cache_path = file.send(:path) if file
      blob_name = "buildpack cache"

      log_and_raise_missing_blob(app.guid, blob_name) unless buildpack_cache_path

      buildpack_cache_url = buildpack_cache_blobstore.download_uri(app.guid)
      download(app, buildpack_cache_path, buildpack_cache_url, blob_name)
    end

    private

    def inject_dependencies(dependencies)
      super
      @blobstore = dependencies.fetch(:droplet_blobstore)
      @buildpack_cache_blobstore = dependencies.fetch(:buildpack_cache_blobstore)
      @package_blobstore = dependencies.fetch(:package_blobstore)
      @config = dependencies.fetch(:config)
    end

    def log_and_raise_missing_blob(app_guid, name)
      Loggregator.emit_error(app_guid, "Did not find #{name} for app with guid: #{app_guid}")
      logger.error "could not find #{name} for #{app_guid}"
      raise StagingError.new("#{name} not found for #{app_guid}")
    end

    def download(app, blob_path, url, name)
      raise InvalidRequest unless blobstore.local?

      logger.debug "guid: #{app.guid} #{name} #{blob_path} #{url}"

      if config[:nginx][:use_nginx]
        logger.debug "nginx redirect #{url}"
        [200, {"X-Accel-Redirect" => url}, ""]
      else
        logger.debug "send_file #{blob_path}"
        send_file blob_path
      end
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
  end
end
