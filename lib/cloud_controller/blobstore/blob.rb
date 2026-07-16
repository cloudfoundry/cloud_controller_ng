module CloudController
  module Blobstore
    class Blob
      CACHE_ATTRIBUTES = %i[etag last_modified created_at content_length].freeze

      def internal_download_url
        raise NotImplementedError
      end

      def public_download_url
        raise NotImplementedError
      end
    end
  end
end
