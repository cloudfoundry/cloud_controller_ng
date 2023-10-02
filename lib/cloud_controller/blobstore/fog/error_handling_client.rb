module CloudController
  module Blobstore
    class ErrorHandlingClient
      extend Forwardable

      def initialize(wrapped_client)
        @wrapped_client = wrapped_client
      end

      def_delegators :@wrapped_client,
                     :local?,
                     :root_dir

      def delete_all(*)
        error_handling { wrapped_client.delete_all(*) }
      end

      def delete_all_in_path(*)
        error_handling { wrapped_client.delete_all_in_path(*) }
      end

      def exists?(*)
        error_handling { wrapped_client.exists?(*) }
      end

      def blob(*)
        error_handling { wrapped_client.blob(*) }
      end

      def files_for(*)
        error_handling { wrapped_client.files_for(*) }
      end

      def delete_blob(*)
        error_handling { wrapped_client.delete_blob(*) }
      end

      def cp_file_between_keys(*)
        error_handling { wrapped_client.cp_file_between_keys(*) }
      end

      def cp_r_to_blobstore(*)
        error_handling { wrapped_client.cp_r_to_blobstore(*)    }
      end

      def download_from_blobstore(*, **)
        error_handling { wrapped_client.download_from_blobstore(*, **) }
      end

      def delete(*)
        error_handling { wrapped_client.delete(*) }
      end

      def cp_to_blobstore(*)
        error_handling { wrapped_client.cp_to_blobstore(*) }
      end

      def ensure_bucket_exists
        error_handling { wrapped_client.ensure_bucket_exists }
      end

      private

      def error_handling
        yield
      rescue StandardError => e
        logger.error("Error with blobstore: #{e.class} - #{e.message}")
        raise BlobstoreError.new(e.message)
      end

      def logger
        @logger ||= Steno.logger('cc.error_handling_client')
      end

      attr_reader :wrapped_client
    end
  end
end
