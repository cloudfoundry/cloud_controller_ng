module CloudController
  module Blobstore
    class Blob
      CACHE_ATTRIBUTES = [:etag, :last_modified, :created_at, :content_length].freeze
    end
  end
end
