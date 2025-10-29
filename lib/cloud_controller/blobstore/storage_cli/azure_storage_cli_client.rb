module CloudController
  module Blobstore
    class AzureStorageCliClient < StorageCliClient
      def cli_path
        ENV['AZURE_STORAGE_CLI_PATH'] || '/var/vcap/packages/azure-storage-cli/bin/azure-storage-cli'
      end

      CloudController::Blobstore::StorageCliClient.register('AzureRM', AzureStorageCliClient)
    end
  end
end
