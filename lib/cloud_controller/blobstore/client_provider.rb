require 'cloud_controller/blobstore/client'
require 'cloud_controller/blobstore/fog/fog_client'
require 'cloud_controller/blobstore/webdav/dav_client'

module CloudController
  module Blobstore
    class ClientProvider
      def self.provide(options:, directory_key:, root_dir: nil)
        cdn_uri = options[:cdn].try(:[], :uri)
        cdn     = CloudController::Blobstore::Cdn.make(cdn_uri)

        FogClient.new(
          options.fetch(:fog_connection),
          directory_key,
          cdn,
          root_dir,
          options[:minimum_size],
          options[:maximum_size]
        )
      end
    end
  end
end
