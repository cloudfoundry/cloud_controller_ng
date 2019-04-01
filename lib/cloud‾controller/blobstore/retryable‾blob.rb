module CloudController
  module Blobstore
    class RetryableBlob < Blob
      extend Forwardable

      attr_reader :wrapped_blob, :retryable_errors, :logger, :num_retries

      def initialize(blob:, errors:, logger:, num_retries: 3)
        @wrapped_blob = blob
        @retryable_errors = errors
        @logger = logger
        @num_retries = num_retries
      end

      def internal_download_url
        with_retries(__method__.to_s, {}) do
          wrapped_blob.internal_download_url
        end
      end

      def public_download_url
        with_retries(__method__.to_s, {}) do
          wrapped_blob.public_download_url
        end
      end

      def attributes(*keys)
        with_retries(__method__.to_s, {
          args: {
            keys: keys,
          }
        }) do
          wrapped_blob.attributes(*keys)
        end
      end

      def local_path
        with_retries(__method__.to_s, {}) do
          wrapped_blob.local_path
        end
      end

      def_delegators :@wrapped_blob,
        :file,
        :key

      private

      def with_retries(log_prefix, log_data)
        retries ||= num_retries
        yield
      rescue *retryable_errors => e
        retries -= 1

        logger.debug("#{log_prefix}-retry",
          {
            error: e.message,
            remaining_retries: retries
          }.merge(log_data)
        )
        retry unless retries == 0
        raise e
      end
    end
  end
end
