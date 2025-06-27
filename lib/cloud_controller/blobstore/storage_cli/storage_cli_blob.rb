module CloudController
  module Blobstore
    class StorageCliBlob < Blob
      attr_reader :key

      def initialize(key, properties: nil, signed_url: nil)
        @key = key
        @signed_url = signed_url if signed_url
        # Set properties to an empty hash if nil to avoid nil errors
        @properties = properties || {}
      end

      def internal_download_url
        signed_url
      end

      def public_download_url
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
