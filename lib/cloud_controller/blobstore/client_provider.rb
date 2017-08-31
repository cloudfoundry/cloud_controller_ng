require 'cloud_controller/blobstore/client'
require 'cloud_controller/blobstore/retryable_client'
require 'cloud_controller/blobstore/fog/fog_client'
require 'cloud_controller/blobstore/fog/error_handling_client'
require 'cloud_controller/blobstore/webdav/dav_client'
require 'cloud_controller/blobstore/safe_delete_client'
require 'bits_service_client'

module CloudController
  module Blobstore
    class ClientProvider
      def self.provide(options:, directory_key:, root_dir: nil, resource_type: nil)
        bits_service_options = VCAP::CloudController::Config.config.get(:bits_service)

        if bits_service_options[:enabled] && resource_type
          provide_bits_service(bits_service_options, resource_type)
        elsif options[:blobstore_type].blank? || (options[:blobstore_type] == 'fog')
          provide_fog(options, directory_key, root_dir)
        else
          provide_webdav(options, directory_key, root_dir)
        end
      end

      class << self
        private

        def provide_fog(options, directory_key, root_dir)
          cdn_uri        = HashUtils.dig(options[:cdn], :uri)
          cdn            = CloudController::Blobstore::Cdn.make(cdn_uri)

          client = FogClient.new(
            connection_config: options.fetch(:fog_connection),
            directory_key: directory_key,
            cdn: cdn,
            root_dir: root_dir,
            min_size: options[:minimum_size],
            max_size: options[:maximum_size],
            storage_options: options[:fog_aws_storage_options]
          )

          logger = Steno.logger('cc.blobstore')

          # work around https://github.com/fog/fog/issues/3137
          # and Fog raising an EOFError SocketError intermittently
          # and https://github.com/fog/fog-aws/issues/264
          # and https://github.com/fog/fog-aws/issues/265
          errors = [Excon::Errors::BadRequest, Excon::Errors::SocketError, SystemCallError,
                    Excon::Errors::InternalServerError, Excon::Errors::ServiceUnavailable]
          retryable_client = RetryableClient.new(client: client, errors: errors, logger: logger)

          Client.new(ErrorHandlingClient.new(SafeDeleteClient.new(retryable_client, root_dir)))
        end

        def provide_bits_service(bits_service_options, resource_type)
          client = BitsService::Client.new(
            bits_service_options: bits_service_options,
            resource_type: resource_type,
            vcap_request_id: VCAP::Request.current_id,
          )

          Client.new(client)
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
