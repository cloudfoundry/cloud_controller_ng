module CloudController
  module Blobstore
    module UrlGeneratorHelpers
      def http_basic_auth_uri(path)
        uri = build_http_uri(path)
        uri.userinfo = [@blobstore_options[:user], @blobstore_options[:password]]
        uri.to_s
      end

      def http_no_auth_uri(path)
        build_http_uri(path).to_s
      end

      def https_no_auth_uri(path)
        build_https_uri(path).to_s
      end

      private

      def build_http_uri(path)
        URI::HTTP.build(
          host:     @blobstore_options[:blobstore_host],
          port:     @blobstore_options[:blobstore_external_port],
          path:     path,
        )
      end

      def build_https_uri(path)
        URI::HTTPS.build(
          host:     @blobstore_options[:blobstore_host],
          port:     @blobstore_options[:blobstore_tls_port],
          path:     path,
        )
      end
    end
  end
end
