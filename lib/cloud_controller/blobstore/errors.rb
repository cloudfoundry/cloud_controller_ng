module CloudController
  module Blobstore
    class FileNotFound < StandardError
    end

    class BlobstoreError < StandardError
    end

    class ConflictError < StandardError
    end

    class UnsafeDelete < StandardError
    end

    class SigningRequestError < BlobstoreError
    end
  end
end
