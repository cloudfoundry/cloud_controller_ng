require 'uri'

module CloudController
  module Blobstore
    class CredhubBlob < Blob
      attr_reader :key
      def initialize(key:)
        @key = key
      end
      def internal_download_url
        "http://cloud-controller-ng.service.cf.internal:9022/v3/blobs?key=#{ERB::Util.url_encode(key)}"
      end

      def public_download_url
        internal_download_url
      end

      def attributes(*keys)
        {}
      end

      def local_path; end
    end
  end
end

