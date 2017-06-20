require 'cloud_controller/blobstore/retryable_blob'

module CloudController
  module Blobstore
    class RetryableClient
      extend Forwardable

      def initialize(client:, errors:, logger:, num_retries: 3)
        @wrapped_client   = client
        @retryable_errors = errors
        @logger = logger
        @num_retries = num_retries
      end

      def_delegators :@wrapped_client,
        :local?,
        :root_dir

      def exists?(key)
        with_retries(__method__.to_s, {
          args: {
            key: key,
          }
        }) do
          @wrapped_client.exists?(key)
        end
      end

      def download_from_blobstore(source_key, destination_path, mode: nil)
        with_retries(__method__.to_s, {
          args: {
            source_key: source_key,
            destination_path: destination_path,
            mode: mode
          }
        }) do
          @wrapped_client.download_from_blobstore(source_key, destination_path, mode: mode)
        end
      end

      def cp_to_blobstore(source_path, destination_key)
        with_retries(__method__.to_s, {
          args: {
            source_path: source_path,
            destination_key: destination_key
          }
        }) do
          @wrapped_client.cp_to_blobstore(source_path, destination_key)
        end
      end

      def cp_r_to_blobstore(source_dir)
        with_retries(__method__.to_s, {
          args: {
            source_dir: source_dir,
          }
        }) do
          @wrapped_client.cp_r_to_blobstore(source_dir)
        end
      end

      def cp_file_between_keys(source_key, destination_key)
        with_retries(__method__.to_s, {
          args: {
            source_key: source_key,
            destination_key: destination_key
          }
        }) do
          @wrapped_client.cp_file_between_keys(source_key, destination_key)
        end
      end

      def delete_all(page_size=FogClient::DEFAULT_BATCH_SIZE)
        with_retries(__method__.to_s, {
          args: {
            page_size: page_size
          }
        }) do
          @wrapped_client.delete_all(page_size)
        end
      end

      def delete_all_in_path(path)
        with_retries(__method__.to_s, {
          args: {
            path: path
          }
        }) do
          @wrapped_client.delete_all_in_path(path)
        end
      end

      def delete(key)
        with_retries(__method__.to_s, {
          args: {
            key: key
          }
        }) do
          @wrapped_client.delete(key)
        end
      end

      def delete_blob(blob)
        with_retries(__method__.to_s, {
          args: {
            blob: blob
          }
        }) do
          @wrapped_client.delete_blob(blob)
        end
      end

      def blob(key)
        with_retries(__method__.to_s, {
          args: {
            key: key
          }
        }) do
          blob = @wrapped_client.blob(key)
          RetryableBlob.new(blob: blob, errors: @retryable_errors, logger: @logger, num_retries: @num_retries) if blob
        end
      end

      def files_for(prefix, ignored_directory_prefixes=[])
        with_retries(__method__.to_s, {
          args: {
            prefix: prefix,
            ignored_directory_prefixes: ignored_directory_prefixes
          }
        }) do
          @wrapped_client.files_for(prefix, ignored_directory_prefixes)
        end
      end

      private

      def with_retries(log_prefix, log_data)
        retries ||= @num_retries
        yield
      rescue *@retryable_errors => e
        retries -= 1

        @logger.debug("#{log_prefix}-retry",
          {
            error:             e.message,
            remaining_retries: retries
          }.merge(log_data)
        )
        retry unless retries == 0
        raise e
      end
    end
  end
end
