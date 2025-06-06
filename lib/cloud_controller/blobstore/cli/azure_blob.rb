module CloudController
  module Blobstore
    class AzureBlob < Blob
      attr_reader :key, :signed_url

      def initialize(key, exists:, signed_url:)
        @key = key
        @exists = exists
        @signed_url = signed_url
      end

      def file
        self
      end

      def exists?
        @exists
      end

      def local_path
        nil
      end

      def internal_download_url
        signed_url
      end

      def public_download_url
        signed_url
      end

      def attributes(*)
        { key: @key }
      end
    end
  end
end
