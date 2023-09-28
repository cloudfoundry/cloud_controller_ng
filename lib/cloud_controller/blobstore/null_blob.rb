module CloudController
  module Blobstore
    class NullBlob < Blob
      def internal_download_url; end

      def public_download_url; end

      def attributes(*_keys)
        {}
      end

      def local_path; end
    end
  end
end
