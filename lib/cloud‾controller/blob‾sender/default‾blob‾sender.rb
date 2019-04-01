module CloudController
  module BlobSender
    class DefaultLocalBlobSender
      def send_blob(blob, controller)
        path = blob.local_path
        logger.debug "send_file #{path}"
        controller.send_file(path)
      end

      def logger
        @logger ||= Steno.logger('cc.default_blob_sender')
      end
    end
  end
end
