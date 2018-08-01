module CloudController
  module BlobSender
    class NginxLocalBlobSender
      def send_blob(blob, controller)
        url = blob.internal_download_url
        logger.debug "nginx redirect #{url}"

        if controller.is_a?(ActionController::Base)
          controller.response_body    = nil
          controller.status           = 200
          controller.response.headers['X-Accel-Redirect'] = url
        else
          return [200, { 'X-Accel-Redirect' => url }, '']
        end
      end

      def logger
        @logger ||= Steno.logger('cc.nginx_blob_sender')
      end
    end
  end
end
