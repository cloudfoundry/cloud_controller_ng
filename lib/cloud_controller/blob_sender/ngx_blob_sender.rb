module CloudController
  module BlobSender
    class NginxLocalBlobSender
      def initialize(missing_blob_handler)
        @missing_blob_handler = missing_blob_handler
      end

      def send_blob(app_guid, blob_name, blob, controller)
        url = blob.download_url
        @missing_blob_handler.handle_missing_blob!(app_guid, blob_name) unless url
        logger.debug "nginx redirect #{url}"
        return [200, {"X-Accel-Redirect" => url}, ""]
      end

      def logger
        @logger ||= Steno.logger("cc.nginx_blob_sender")
      end
    end
  end
end

