module CloudController
  module Blobstore
    # Central place to get download urls for a blob object stored in a blobstore
    class Blob

      CACHE_ATTRIBUTES = [:etag, :last_modified, :created_at]

      attr_reader :file

      def initialize(file, cdn)
        @file = file
        @cdn = cdn
      end

      def local_path
        file.send(:path)
      end

      def download_url
        return download_uri_for_file
      end

      def public_url
        file.public_url
      end

      def attributes(*keys)
        return file.attributes if keys.empty?
        file.attributes.select {|key,_| keys.include? key}
      end

      private
      def download_uri_for_file
        if @cdn
          return @cdn.download_uri(file.key)
        end

        if file.respond_to?(:url)
          return file.url(Time.now + 3600)
        end
        return file.public_url
      end
    end
  end
end
