module CloudController
  module Blobstore
    class HTTPClientProvider
      def self.provide(ca_cert_path: nil)
        client = HTTPClient.new
        client.ssl_config.verify_mode = VCAP::CloudController::Config.config[:skip_cert_verify] ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
        client.ssl_config.set_default_paths

        if ca_cert_path && File.exist?(ca_cert_path)
          client.ssl_config.add_trust_ca(ca_cert_path)
        end

        client
      end
    end
  end
end
