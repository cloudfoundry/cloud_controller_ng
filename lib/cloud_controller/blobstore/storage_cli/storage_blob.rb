module CloudController
  module Blobstore
    class StorageBlob < Blob
      attr_reader :key

      def initialize(key, signed_url:)
        @key = key
        @signed_url = signed_url
      end
      def internal_download_url
        signed_url
      end

      def public_download_url
        signed_url
      end

      def attributes(*keys)
        attrs = {
          etag: nil,
          last_modified: nil,
          created_at: nil,
          content_length: nil,
          key: @key
        }
        keys.empty? ? attrs : attrs.slice(*keys)
      end
    end
  end
end
