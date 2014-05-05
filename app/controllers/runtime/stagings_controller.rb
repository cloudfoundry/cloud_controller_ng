require "cloudfront-signer"
require "cloud_controller/blobstore/client"

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
      app = App.find(guid: guid)
      check_app_exists(app, guid)

      blob = package_blobstore.blob(guid)
      unless blob
        logger.error "could not find package for #{guid}"
        raise ApiError.new_from_details("AppPackageNotFound", guid)
      end
      @blob_sender.send_blob(app.guid, "AppPackage", blob, self)
    end

    post "#{DROPLET_PATH}/:guid/upload", :upload_droplet
    def upload_droplet(guid)
      app = App.find(:guid => guid)

      check_app_exists(app, guid)
      check_file_was_uploaded(app)
      check_file_md5

      logger.info "droplet.begin-upload", :app_guid => app.guid

      droplet_upload_job = Jobs::Runtime::DropletUpload.new(upload_path, app.id)

      if async?
        job = Jobs::Enqueuer.new(droplet_upload_job, queue: LocalQueue.new(config)).enqueue()
        external_domain = Array(config[:external_domain]).first
        [HTTP::OK, JobPresenter.new(job, "#{config[:external_protocol]}://#{external_domain}").to_json]
      else
        droplet_upload_job.perform
        HTTP::OK
      end
    end

    get "#{DROPLET_PATH}/:guid/download", :download_droplet
    def download_droplet(guid)
      app = App.find(:guid => guid)
      check_app_exists(app, guid)
      droplet = app.current_droplet
      blob_name = "droplet"
      @missing_blob_handler.handle_missing_blob!(app.guid, blob_name) unless droplet.blob
      @blob_sender.send_blob(app.guid, blob_name, droplet.blob, self)
    end

    post "#{BUILDPACK_CACHE_PATH}/:guid/upload", :upload_buildpack_cache
    def upload_buildpack_cache(guid)
      app = App.find(:guid => guid)

      check_app_exists(app, guid)
      check_file_was_uploaded(app)
      check_file_md5

      blobstore_upload = Jobs::Runtime::BlobstoreUpload.new(upload_path, app.guid, :buildpack_cache_blobstore)
      Jobs::Enqueuer.new(blobstore_upload, queue: LocalQueue.new(config)).enqueue()
      HTTP::OK
    end

    get "#{BUILDPACK_CACHE_PATH}/:guid/download", :download_buildpack_cache
    def download_buildpack_cache(guid)
      app = App.find(:guid => guid)
      check_app_exists(app, guid)

      blob = buildpack_cache_blobstore.blob(app.guid)
      blob_name = "buildpack cache"

      @missing_blob_handler.handle_missing_blob!(app.guid, blob_name) unless blob
      @blob_sender.send_blob(app.guid, blob_name, blob, self)
    end

    private
    def inject_dependencies(dependencies)
      super
      @blobstore = dependencies.fetch(:droplet_blobstore)
      @buildpack_cache_blobstore = dependencies.fetch(:buildpack_cache_blobstore)
      @package_blobstore = dependencies.fetch(:package_blobstore)
      @config = dependencies.fetch(:config)
      @missing_blob_handler = dependencies.fetch(:missing_blob_handler)
      @blob_sender = dependencies.fetch(:blob_sender)
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

    def check_app_exists(app, guid)
      raise ApiError.new_from_details("AppNotFound", guid) if app.nil?
    end

    def check_file_was_uploaded(app)
      raise ApiError.new_from_details("StagingError", "malformed droplet upload request for #{app.guid}") unless upload_path
    end

    def check_file_md5
      file_md5 = Digest::MD5.base64digest(File.read(upload_path))
      header_md5 = env["HTTP_CONTENT_MD5"]
      if header_md5.present? && file_md5 != header_md5
        raise ApiError.new_from_details("StagingError", "content md5 did not match")
      end
    end
  end
end
