module CloudController
  module Blobstore
    class Blob
      CACHE_ATTRIBUTES = [:etag, :last_modified, :created_at]

      def download_url
        raise NotImplementedError
      end

      def attributes(_)
        raise NotImplementedError
      end
    end
  end
end
