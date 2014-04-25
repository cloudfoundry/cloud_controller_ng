module CloudController
  module BlobSender
    class DefaultLocalBlobSender
      def initialize(missing_blob_handler)
        @missing_blob_handler = missing_blob_handler
      end

      def send_blob(app_guid, blob_name, blob, controller)
        path = blob.local_path
        if path
          logger.debug "send_file #{path}"
          controller.send_file(path)
        else
          @missing_blob_handler.handle_missing_blob!(app_guid, blob_name)
        end
      end

      def logger
        @logger ||= Steno.logger("cc.default_blob_sender")
      end
    end
  end
end