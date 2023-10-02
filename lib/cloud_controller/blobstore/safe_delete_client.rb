module CloudController
  module Blobstore
    class SafeDeleteClient
      extend Forwardable

      attr_reader :wrapped_client

      def initialize(client, root_dir)
        @wrapped_client = client
        @root_dir       = root_dir
      end

      def delete_all(*)
        raise UnsafeDelete.new('it is only safe to call delete_all on blobstores with a root directory') if @root_dir.blank?

        @wrapped_client.delete_all(*)
      end

      def delete_all_in_path(*)
        raise UnsafeDelete.new('it is only safe to call delete_all on blobstores with a root directory') if @root_dir.blank?

        @wrapped_client.delete_all_in_path(*)
      end

      def_delegators :@wrapped_client,
                     :local?,
                     :exists?,
                     :download_from_blobstore,
                     :cp_to_blobstore,
                     :cp_r_to_blobstore,
                     :cp_file_between_keys,
                     :delete,
                     :delete_blob,
                     :download_uri,
                     :blob,
                     :files_for,
                     :root_dir,
                     :ensure_bucket_exists
    end
  end
end
