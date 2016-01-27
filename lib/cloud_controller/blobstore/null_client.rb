require 'cloud_controller/blobstore/base_client'

module CloudController
  module Blobstore
    class NullClient < BaseClient
      def local?
        false
      end

      def exists?(key)
        false
      end

      def download_from_blobstore(source_key, destination_path, mode: nil)
      end

      def cp_to_blobstore(source_path, destination_key, retries=2)
      end

      def cp_file_between_keys(source_key, destination_key)
      end

      def delete_all(page_size=DEFAULT_BATCH_SIZE)
      end

      def delete_all_in_path(path)
      end

      def delete(key)
      end

      def delete_blob(blob)
      end

      def download_uri(key)
        'http://example.com/nullclient/download_uri'
      end

      def blob(key)
        Blob.new
      end
    end
  end
end
