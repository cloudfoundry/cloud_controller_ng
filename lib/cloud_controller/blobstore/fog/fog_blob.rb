module CloudController
  module Blobstore
    class FogBlob < Blob
      attr_reader :file

      def initialize(file, cdn)
        @file = file
        @cdn = cdn
      end

      def local_path
        file.send(:path)
      end

      def internal_download_url
        download_uri_for_file
      end

      def public_download_url
        download_uri_for_file
      end

      def attributes(*keys)
        return file.attributes if keys.empty?

        file.attributes.select { |key, _| keys.include? key }
      end

      private

      def download_uri_for_file
        return @cdn.download_uri(file.key) if @cdn

        return file.url(Time.now.utc + 3600) if file.respond_to?(:url)

        file.public_url
      end
    end
  end
end
