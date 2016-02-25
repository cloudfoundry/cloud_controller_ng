module CloudController
  module BlobSender
    class NginxLocalBlobSender
      def send_blob(blob, controller)
        url = blob.internal_download_url
        logger.debug "nginx redirect #{url}"
        [200, { 'X-Accel-Redirect' => url }, '']
      end

      def logger
        @logger ||= Steno.logger('cc.nginx_blob_sender')
      end
    end
  end
end
