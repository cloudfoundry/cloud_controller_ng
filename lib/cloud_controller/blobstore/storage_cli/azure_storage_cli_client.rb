module CloudController
  module Blobstore
    class AzureStorageCliClient < StorageCliClient
      def cli_path
        ENV['AZURE_STORAGE_CLI_PATH'] || '/var/vcap/packages/azure-storage-cli/bin/azure-storage-cli'
      end

      def build_config(connection_config)
        {
          account_name: connection_config[:azure_storage_account_name],
          account_key: connection_config[:azure_storage_access_key],
          container_name: @directory_key,
          environment: connection_config[:environment]
        }.compact
      end

      CloudController::Blobstore::StorageCliClient.register('AzureRM', AzureStorageCliClient)
    end
  end
end
