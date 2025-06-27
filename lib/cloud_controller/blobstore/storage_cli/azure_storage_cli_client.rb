module CloudController
  module Blobstore
    class AzureStorageCliClient < StorageCliClient
      StorageCliClient.register('AzureRM', CloudController::Blobstore::AzureStorageCliClient)

      def cli_path
        ENV['AZURE_STORAGE_CLI_PATH'] || '/var/vcap/packages/azure-storage-cli/bin/azure-storage-cli'
      end

      def build_config(fog_connection)
        {
          account_name: fog_connection[:azure_storage_account_name],
          account_key: fog_connection[:azure_storage_access_key],
          container_name: @directory_key,
          environment: fog_connection[:environment]
        }.compact
      end
    end
  end
end
