module VCAP::CloudController
  class BlobDispatcher
    def initialize(blobstore:, controller:)
      @blobstore = blobstore
      @controller = controller
    end

    def send_or_redirect(guid:)
      raise CloudController::Errors::BlobNotFound unless guid
      blob = @blobstore.blob(guid)
      raise CloudController::Errors::BlobNotFound unless blob
      send_or_redirect_blob(blob)
    end

    def send_or_redirect_blob(blob)
      raise CloudController::Errors::BlobNotFound unless blob
      if @blobstore.local?
        blob_sender.send_blob(blob, @controller)
      else
        begin
          if @controller.is_a?(ActionController::Base)
            @controller.redirect_to blob.public_download_url
          else
            @controller.redirect blob.public_download_url
          end
        rescue CloudController::Blobstore::SigningRequestError => e
          logger.error("failed to get download url: #{e.message}")
          raise CloudController::Errors::ApiError.new_from_details('BlobstoreUnavailable')
        end
      end
    end

    private

    def logger
      @logger ||= Steno.logger('cc.blob_dispatcher')
    end

    def blob_sender
      @blob_sender ||= CloudController::DependencyLocator.instance.blob_sender
    end
  end
end
