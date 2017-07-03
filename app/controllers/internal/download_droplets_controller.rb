require 'cloudfront-signer'
require 'cloud_controller/blobstore/client'

module VCAP::CloudController
  class DownloadDropletsController < RestController::BaseController
    def self.dependencies
      [:droplet_blobstore, :blobstore_url_generator, :missing_blob_handler, :blob_sender, :droplet_url_generator]
    end

    include CloudController::Errors

    # Endpoint does its own basic auth
    allow_unauthenticated_access

    attr_reader :blobstore

    get '/internal/v2/droplets/:guid/:droplet_checksum/download', :download_droplet_http

    def download_droplet_http(guid, droplet_checksum)
      if @droplet_url_generator.mtls
        url = @droplet_url_generator.perma_droplet_download_url(guid, droplet_checksum)
        redirect url
      else
        download_droplet(guid, droplet_checksum)
      end
    end

    get '/internal/v4/droplets/:guid/:droplet_checksum/download', :download_droplet_mtls

    def download_droplet_mtls(guid, droplet_checksum)
      download_droplet(guid, droplet_checksum)
    end

    private

    def inject_dependencies(dependencies)
      super
      @blobstore               = dependencies.fetch(:droplet_blobstore)
      @blobstore_url_generator = dependencies.fetch(:blobstore_url_generator)
      @missing_blob_handler    = dependencies.fetch(:missing_blob_handler)
      @blob_sender             = dependencies.fetch(:blob_sender)
      @droplet_url_generator   = dependencies.fetch(:droplet_url_generator)
    end

    def check_app_exists(app, guid)
      raise ApiError.new_from_details('AppNotFound', guid) if app.nil?
    end

    def download_droplet(guid, droplet_checksum)
      process = ProcessModel.find(guid: guid)
      check_app_exists(process, guid)
      raise ApiError.new_from_details('NotFound', droplet_checksum) unless process.droplet_checksum == droplet_checksum

      blob_name = 'droplet'
      droplet   = process.current_droplet

      if @blobstore.local?
        blob = @blobstore.blob(droplet.blobstore_key)
        @missing_blob_handler.handle_missing_blob!(process.guid, blob_name) unless droplet && blob
        @blob_sender.send_blob(blob, self)
      else
        url = @blobstore_url_generator.droplet_download_url(droplet)
        @missing_blob_handler.handle_missing_blob!(process.guid, blob_name) unless url
        redirect url
      end
    end
  end
end
