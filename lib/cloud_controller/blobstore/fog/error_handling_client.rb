module CloudController
  module Blobstore
    class ErrorHandlingClient
      def initialize(wrapped_client)
        @wrapped_client = wrapped_client
      end

      def local?
        wrapped_client.local?
      end

      def delete_all(*args)
        error_handling { wrapped_client.delete_all(*args) }
      end

      def delete_all_in_path(*args)
        error_handling { wrapped_client.delete_all_in_path(*args) }
      end

      def exists?(*args)
        error_handling { wrapped_client.exists?(*args) }
      end

      def blob(*args)
        error_handling { wrapped_client.blob(*args) }
      end

      def delete_blob(*args)
        error_handling { wrapped_client.delete_blob(*args) }
      end

      def cp_file_between_keys(*args)
        error_handling { wrapped_client.cp_file_between_keys(*args) }
      end

      def cp_r_to_blobstore(*args)
        error_handling { wrapped_client.cp_r_to_blobstore(*args) }
      end

      def download_from_blobstore(*args)
        error_handling { wrapped_client.download_from_blobstore(*args) }
      end

      def delete(*args)
        error_handling { wrapped_client.delete(*args) }
      end

      def cp_to_blobstore(*args)
        error_handling { wrapped_client.cp_to_blobstore(*args) }
      end

      private

      def error_handling
        yield
      rescue Excon::Errors::Error => e
        raise BlobstoreError.new(e.message)
      end

      attr_reader :wrapped_client
    end
  end
end
