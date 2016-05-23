require 'cloud_controller/blobstore/client'
require 'cloud_controller/blobstore/retryable_client'
require 'cloud_controller/blobstore/fog/fog_client'
require 'cloud_controller/blobstore/fog/error_handling_client'
require 'cloud_controller/blobstore/webdav/dav_client'
require 'cloud_controller/blobstore/safe_delete_client'

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

      class << self
        private

        def provide_fog(options, directory_key, root_dir)
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

          logger = Steno.logger('cc.blobstore')

          # work around https://github.com/fog/fog/issues/3137
          # and Fog raising an EOFError SocketError intermittently
          errors = [Excon::Errors::BadRequest, Excon::Errors::SocketError, SystemCallError]
          retryable_client = RetryableClient.new(client: client, errors: errors, logger: logger)

          Client.new(ErrorHandlingClient.new(SafeDeleteClient.new(retryable_client, root_dir)))
        end

        def provide_webdav(options, directory_key, root_dir)
          client = DavClient.build(
            options.fetch(:webdav_config),
            directory_key,
            root_dir,
            options[:minimum_size],
            options[:maximum_size]
          )

          logger = Steno.logger('cc.blobstore.dav_client')
          errors = [StandardError]
          retryable_client = RetryableClient.new(client: client, errors: errors, logger: logger)

          Client.new(SafeDeleteClient.new(retryable_client, root_dir))
        end
      end
    end
  end
end
