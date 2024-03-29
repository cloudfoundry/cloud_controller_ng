require 'cloud_controller/blobstore/base_client'

module CloudController
  module Blobstore
    class NullClient < BaseClient
      def local?
        false
      end

      def exists?(_key)
        false
      end

      def download_from_blobstore(source_key, destination_path, mode: nil); end

      def cp_to_blobstore(source_path, destination_key, retries=2); end

      def cp_file_between_keys(source_key, destination_key); end

      def delete_all(page_size=DEFAULT_BATCH_SIZE); end

      def delete_all_in_path(path); end

      def delete(key); end

      def delete_blob(blob); end

      def download_uri(_key)
        'http://example.com/nullclient/download_uri'
      end

      def ensure_bucket_exists; end

      def blob(_key)
        Blob.new
      end

      def files_for(prefix, ignored_directories=[]); end
    end
  end
end
