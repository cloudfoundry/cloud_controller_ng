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

    def upload_droplet(guid)
      app = App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?
      raise StagingError.new("malformed droplet upload request for #{app.guid}") unless upload_path

      logger.info "droplet.begin-upload", :app_guid => app.guid

      #TODO: put in background job
      start = Time.now
      CloudController::BlobstoreDroplet.new(app, blobstore).save(upload_path)
      logger.info "droplet.uploaded", took: Time.now - start, :app_guid => app.guid
      app.save
      logger.info "droplet.saved", :sha => app.droplet_hash, :app_guid => app.guid

      HTTP::OK
    ensure
      FileUtils.rm_f(upload_path) if upload_path
    end

    def upload_buildpack_cache(guid)
      app = App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?
      raise StagingError.new("malformed buildpack cache upload request for #{app.guid}") unless upload_path

      logger.info "buildpack.begin-upload", :app_guid => app.guid

      buildpack_cache_blobstore.cp_to_blobstore(
        upload_path,
        app.guid
      )

      logger.info "buildpack.uploaded", :app_guid => app.guid

      HTTP::OK
    ensure
      FileUtils.rm_f(upload_path) if upload_path
    end

    def download_droplet(guid)
      app = App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?

      droplet = CloudController::BlobstoreDroplet.new(app, blobstore)
      droplet_path = droplet.local_path
      droplet_url = droplet.download_url

      download(app, droplet_path, droplet_url, "droplet")
    end

    def download_buildpack_cache(guid)
      app = App.find(:guid => guid)
      raise AppNotFound.new(guid) if app.nil?

      file = buildpack_cache_blobstore.file(app.guid)
      buildpack_cache_path = file.send(:path) if file
      buildpack_cache_url = buildpack_cache_blobstore.download_uri(app.guid)
      download(app, buildpack_cache_path, buildpack_cache_url, "buildpack cache")
    end

    def inject_dependencies(dependencies)
      @blobstore = dependencies.fetch(:droplet_blobstore)
      @buildpack_cache_blobstore = dependencies.fetch(:buildpack_cache_blobstore)
      @package_blobstore = dependencies.fetch(:package_blobstore)
    end
    private

    def download(app, blob_path, url, name)
      raise InvalidRequest unless blobstore.local?

      logger.debug "guid: #{app.guid} #{name} #{blob_path} #{url}"

      unless blob_path
        Loggregator.emit_error(app.guid, "Did not find #{name} for app with guid: #{app.guid}")
        logger.error "could not find #{name} for #{app.guid}"
        raise StagingError.new("#{name} not found for #{app.guid}")
      end

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

    get "/staging/apps/:guid", :download_app

    # Make sure that nginx upload path rules do not apply to download paths!
    post "#{DROPLET_PATH}/:guid/upload", :upload_droplet
    get "#{DROPLET_PATH}/:guid/download", :download_droplet

    post "#{BUILDPACK_CACHE_PATH}/:guid/upload", :upload_buildpack_cache
    get "#{BUILDPACK_CACHE_PATH}/:guid/download", :download_buildpack_cache
  end
end
