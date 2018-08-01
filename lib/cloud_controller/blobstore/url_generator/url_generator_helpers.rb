module CloudController
  module Blobstore
    module UrlGeneratorHelpers
      def basic_auth_uri(path)
        uri = build_uri(path)
        uri.userinfo = [@blobstore_options[:user], @blobstore_options[:password]]
        uri.to_s
      end

      def no_auth_uri(path)
        build_uri(path).to_s
      end

      def build_uri(path)
        URI::HTTP.build(
          host:     @blobstore_options[:blobstore_host],
          port:     @blobstore_options[:blobstore_port],
          path:     path,
        )
      end
    end
  end
end
