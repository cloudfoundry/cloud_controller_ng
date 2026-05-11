module CloudController
  module Blobstore
    class StorageCliBlob < Blob
      attr_reader :key

      def initialize(key, properties: nil, signed_url: nil, storage_cli_client: nil, expires_in_seconds: 3600)
        @key = key
        @signed_url = signed_url if signed_url
        @storage_cli_client = storage_cli_client
        @expires_in_seconds = expires_in_seconds
        # Set properties to an empty hash if nil to avoid nil errors
        @properties = properties || {}
      end

      def internal_download_url
        # For DAV with lazy signing support, generate URL on-demand
        return @storage_cli_client.sign_internal_url(@key, verb: 'get', expires_in_seconds: @expires_in_seconds) if @storage_cli_client&.supports_lazy_signing?

        signed_url
      end

      def public_download_url
        # For DAV with lazy signing support, generate URL on-demand
        return @storage_cli_client.sign_public_url(@key, verb: 'get', expires_in_seconds: @expires_in_seconds) if @storage_cli_client&.supports_lazy_signing?

        signed_url
      end

      def attributes(*keys)
        @attributes ||= {
          etag: @properties.fetch('etag', nil),
          last_modified: @properties.fetch('last_modified', nil),
          content_length: @properties.fetch('content_length', nil),
          created_at: @properties.fetch('created_at', nil)
        }

        return @attributes if keys.empty?

        @attributes.select { |key, _| keys.include? key }
      end

      private

      def signed_url
        raise BlobstoreError.new('StorageCliBlob not configured with a signed URL') unless @signed_url

        @signed_url
      end
    end
  end
end
