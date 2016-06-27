module CloudController
  module Blobstore
    class BitsServiceBlob
      attr_reader :guid, :public_download_url, :internal_download_url

      def initialize(guid:, public_download_url:, internal_download_url:)
        @guid = guid
        @public_download_url = public_download_url
        @internal_download_url = internal_download_url
      end

      def attributes(*_)
        []
      end
    end
  end
end
