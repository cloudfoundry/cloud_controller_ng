module CloudController
  module Blobstore
    class AliStorageCliClient < StorageCliClient
      def cli_path
        ENV['ALI_STORAGE_CLI_PATH'] || '/var/vcap/packages/ali-storage-cli/bin/ali-storage-cli'
      end

      CloudController::Blobstore::StorageCliClient.register('aliyun', AliStorageCliClient)
    end
  end
end
