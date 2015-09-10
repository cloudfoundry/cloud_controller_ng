require 'cloudfront-signer'
require 'cloud_controller/blobstore/client'

module VCAP::CloudController
  class DownloadDropletsController < RestController::BaseController
    def self.dependencies
      [:droplet_blobstore, :blobstore_url_generator, :missing_blob_handler, :blob_sender]
    end

    include VCAP::Errors

    DROPLET_V2_PATH = '/internal/v2/droplets'

    # Endpoint does its own basic auth
    allow_unauthenticated_access

    attr_reader :blobstore

    get "#{DROPLET_V2_PATH}/:guid/:droplet_hash/download", :download_droplet
    def download_droplet(guid, droplet_hash)
      app = App.find(guid: guid)
      check_app_exists(app, guid)
      raise ApiError.new_from_details('NotFound', droplet_hash) unless app.droplet_hash == droplet_hash

      blob_name = 'droplet'

      if @blobstore.local?
        if app.is_v3?
          droplet = app.app.droplet
          blob = @blobstore.blob(droplet.blobstore_key)
        else
          droplet = app.current_droplet
          blob = droplet.blob
        end

        @missing_blob_handler.handle_missing_blob!(app.guid, blob_name) unless droplet && blob
        @blob_sender.send_blob(app.guid, blob_name, blob, self)
      else
        url = nil
        if app.is_v3?
          url = @blobstore_url_generator.v3_droplet_download_url(app.app.droplet)
        else
          url = @blobstore_url_generator.droplet_download_url(app)
        end

        @missing_blob_handler.handle_missing_blob!(app.guid, blob_name) unless url
        redirect url
      end
    end

    private

    def inject_dependencies(dependencies)
      super
      @blobstore = dependencies.fetch(:droplet_blobstore)
      @blobstore_url_generator = dependencies.fetch(:blobstore_url_generator)
      @missing_blob_handler = dependencies.fetch(:missing_blob_handler)
      @blob_sender = dependencies.fetch(:blob_sender)
    end

    def check_app_exists(app, guid)
      raise ApiError.new_from_details('AppNotFound', guid) if app.nil?
    end
  end
end
