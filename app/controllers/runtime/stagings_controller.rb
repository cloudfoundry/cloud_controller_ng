require 'cloudfront-signer'
require 'cloud_controller/blobstore/client'
require 'presenters/api/staging_job_presenter'
require 'utils/hash_utils'

module VCAP::CloudController
  class StagingsController < RestController::BaseController
    def self.dependencies
      [:droplet_blobstore, :buildpack_cache_blobstore, :package_blobstore,
       :blobstore_url_generator, :missing_blob_handler, :blob_sender, :config]
    end

    include CloudController::Errors

    # Endpoint does its own basic auth
    allow_unauthenticated_access

    authenticate_basic_auth('/staging/*') do
      [VCAP::CloudController::Config.config[:staging][:auth][:user],
       VCAP::CloudController::Config.config[:staging][:auth][:password]]
    end

    attr_reader :config, :blobstore, :buildpack_cache_blobstore, :package_blobstore

    get '/staging/jobs/:guid', :find_job
    def find_job(guid)
      job = Delayed::Job[guid: guid]
      StagingJobPresenter.new(job).to_json
    end

    get '/staging/packages/:guid', :download_package
    def download_package(guid)
      raise ApiError.new_from_details('BlobstoreNotLocal') unless package_blobstore.local?

      package = PackageModel.find(guid: guid)
      raise ApiError.new_from_details('NotFound', guid) if package.nil?

      blob = package_blobstore.blob(guid)
      if blob.nil?
        logger.error "could not find package for #{guid}"
        raise ApiError.new_from_details('NotFound', guid)
      end
      @blob_sender.send_blob(blob, self)
    end

    get '/staging/v3/droplets/:guid/download', :download_v3_droplet
    def download_v3_droplet(guid)
      raise ApiError.new_from_details('BlobstoreNotLocal') unless @blobstore.local?

      droplet = DropletModel.find(guid: guid)
      raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', 'Package not found') if droplet.nil?

      blob = @blobstore.blob(droplet.blobstore_key)
      blob_name = "droplet_#{droplet.guid}"

      @missing_blob_handler.handle_missing_blob!(droplet.blobstore_key, blob_name) unless blob
      @blob_sender.send_blob(blob, self)
    end

    post '/staging/v3/droplets/:guid/upload', :upload_package_droplet
    def upload_package_droplet(guid)
      droplet = DropletModel.find(guid: guid)

      raise ApiError.new_from_details('NotFound', guid) if droplet.nil?
      raise ApiError.new_from_details('StagingError', "malformed droplet upload request for #{guid}") unless upload_path
      check_file_md5

      logger.info 'v3-droplet.begin-upload', droplet_guid: guid

      droplet_upload_job = Jobs::V3::DropletUpload.new(upload_path, guid)

      job = Jobs::Enqueuer.new(droplet_upload_job, queue: Jobs::LocalQueue.new(config)).enqueue
      [HTTP::OK, StagingJobPresenter.new(job).to_json]
    end

    post '/staging/v3/buildpack_cache/:stack_name/:guid/upload', :upload_v3_app_buildpack_cache
    def upload_v3_app_buildpack_cache(stack_name, guid)
      app_model = AppModel.find(guid: guid)

      raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found') if app_model.nil?
      raise ApiError.new_from_details('StagingError', "malformed buildpack cache upload request for #{guid}") unless upload_path
      check_file_md5

      cache_key = Presenters::V3::CacheKeyPresenter.cache_key(guid: guid, stack_name: stack_name)

      blobstore_upload = Jobs::Runtime::BlobstoreUpload.new(upload_path, cache_key, :buildpack_cache_blobstore)
      Jobs::Enqueuer.new(blobstore_upload, queue: Jobs::LocalQueue.new(config)).enqueue
      HTTP::OK
    end

    get '/staging/v3/buildpack_cache/:stack/:guid/download', :download_v3_app_buildpack_cache
    def download_v3_app_buildpack_cache(stack_name, guid)
      app_model = AppModel.find(guid: guid)
      raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found') if app_model.nil?

      logger.info 'v3-droplet.begin-download', app_guid: guid, stack: stack_name

      blob = buildpack_cache_blobstore.blob("#{guid}/#{stack_name}")
      blob_name = 'buildpack cache'

      @missing_blob_handler.handle_missing_blob!(guid, blob_name) unless blob
      @blob_sender.send_blob(blob, self)
    end

    private

    def inject_dependencies(dependencies)
      super
      @blobstore = dependencies.fetch(:droplet_blobstore)
      @buildpack_cache_blobstore = dependencies.fetch(:buildpack_cache_blobstore)
      @package_blobstore = dependencies.fetch(:package_blobstore)
      @blobstore_url_generator = dependencies.fetch(:blobstore_url_generator)
      @config = dependencies.fetch(:config)
      @missing_blob_handler = dependencies.fetch(:missing_blob_handler)
      @blob_sender = dependencies.fetch(:blob_sender)
    end

    def upload_path
      @upload_path ||=
        if HashUtils.dig(config, :nginx, :use_nginx)
          params['droplet_path']
        elsif (tempfile = HashUtils.dig(params, 'file', :tempfile))
          tempfile.path
        elsif (tempfile = HashUtils.dig(params, 'upload', 'droplet', :tempfile))
          tempfile.path
        end
    end

    def check_file_md5
      digester = Digester.new(algorithm: Digest::MD5, type: :base64digest)
      file_md5 = digester.digest_path(upload_path)
      header_md5 = env['HTTP_CONTENT_MD5']

      if header_md5.present? && file_md5 != header_md5
        raise ApiError.new_from_details('StagingError', 'content md5 did not match')
      end
    end
  end
end
