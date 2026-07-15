require 'cloud_controller/blobstore/client'
require 'cloud_controller/blobstore/retryable_client'
require 'cloud_controller/blobstore/error_handling_client'
require 'cloud_controller/blobstore/webdav/dav_client'
require 'cloud_controller/blobstore/local/local_client'
require 'cloud_controller/blobstore/safe_delete_client'
require 'cloud_controller/blobstore/storage_cli/storage_cli_client'

module CloudController
  module Blobstore
    class ClientProvider
      def self.provide(options:, directory_key:, root_dir: nil, resource_type: nil)
        case options[:blobstore_type]
        when 'local'
          provide_local(options, directory_key, root_dir, use_temp_storage: false)
        when 'local-temp-storage'
          provide_local(options, directory_key, root_dir, use_temp_storage: true)
        when 'storage-cli'
          provide_storage_cli(options, directory_key, root_dir, resource_type)
        else
          provide_webdav(options, directory_key, root_dir)
        end
      end

      class << self
        private

        def provide_local(options, directory_key, root_dir, use_temp_storage:)
          client = LocalClient.new(
            directory_key: directory_key,
            base_path: options[:local_blobstore_path],
            root_dir: root_dir,
            min_size: options[:minimum_size],
            max_size: options[:maximum_size],
            use_temp_storage: use_temp_storage
          )

          logger = Steno.logger('cc.blobstore.local_client')
          errors = [StandardError]
          retryable_client = RetryableClient.new(client:, errors:, logger:)

          Client.new(SafeDeleteClient.new(retryable_client, root_dir))
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
          retryable_client = RetryableClient.new(client:, errors:, logger:)

          Client.new(SafeDeleteClient.new(retryable_client, root_dir))
        end

        def provide_storage_cli(options, directory_key, root_dir, resource_type)
          client = StorageCliClient.new(
            directory_key: directory_key,
            resource_type: resource_type,
            root_dir: root_dir,
            min_size: options[:minimum_size],
            max_size: options[:maximum_size]
          )

          logger = Steno.logger('cc.blobstore.storage_cli_client')
          errors = [StandardError]
          retryable_client = RetryableClient.new(client:, errors:, logger:)

          Client.new(SafeDeleteClient.new(retryable_client, root_dir))
        end
      end
    end
  end
end
