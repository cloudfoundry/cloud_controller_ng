module VCAP::CloudController
  class BlobDispatcher
    def initialize(blob_sender:, controller:)
      @blob_sender = blob_sender
      @controller = controller
    end

    def send_or_redirect(local:, blob:)
      if local
        @blob_sender.send_blob(blob, @controller)
      else
        begin
          @controller.redirect blob.public_download_url
        rescue CloudController::Blobstore::SigningRequestError => e
          logger.error("failed to get download url: #{e.message}")
          raise VCAP::Errors::ApiError.new_from_details('BlobstoreUnavailable')
        end
      end
    end

    private

    def logger
      @logger ||= Steno.logger('cc.blob_dispatcher')
    end
  end
end
