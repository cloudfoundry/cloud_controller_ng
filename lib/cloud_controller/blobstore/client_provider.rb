require 'cloud_controller/blobstore/client'
require 'cloud_controller/blobstore/fog/fog_client'
require 'cloud_controller/blobstore/webdav/dav_client'

module CloudController
  module Blobstore
    class ClientProvider
      def self.provide(options:, directory_key:, root_dir: nil)
        if options[:blobstore_type].blank? || (options[:blobstore_type] == 'fog')
          provide_fog(options, directory_key, root_dir)
        else
          provide_webdav(options, directory_key, root_dir)
        end
      end

      def self.provide_fog(options, directory_key, root_dir)
        cdn_uri = options[:cdn].try(:[], :uri)
        cdn     = CloudController::Blobstore::Cdn.make(cdn_uri)

        client = FogClient.new(
          options.fetch(:fog_connection),
          directory_key,
          cdn,
          root_dir,
          options[:minimum_size],
          options[:maximum_size]
        )

        Client.new(client)
      end

      def self.provide_webdav(options, directory_key, root_dir)
        client = DavClient.new(
          options,
          directory_key,
          options[:minimum_size],
          options[:maximum_size]
        )

        Client.new(client)
      end
    end
  end
end
