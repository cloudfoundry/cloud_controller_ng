module CloudController
  module Blobstore
    class Blob
      CACHE_ATTRIBUTES = %i[etag last_modified created_at content_length].freeze

      def key
        raise NotImplementedError
      end
    end
  end
end
