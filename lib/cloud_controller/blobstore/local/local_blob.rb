require 'cloud_controller/blobstore/blob'
require 'openssl'

module CloudController
  module Blobstore
    class LocalBlob < Blob
      attr_reader :key

      def initialize(key:, file_path:)
        @key       = key
        @file_path = file_path
      end

      def internal_download_url
        nil
      end

      def public_download_url
        nil
      end

      def local_path
        @file_path
      end

      def attributes(*keys)
        @attributes ||= begin
          stat = File.stat(@file_path)
          {
            etag: OpenSSL::Digest::MD5.file(@file_path).hexdigest,
            last_modified: stat.mtime.httpdate,
            content_length: stat.size.to_s,
            created_at: stat.ctime
          }
        end

        return @attributes if keys.empty?

        @attributes.slice(*keys)
      end
    end
  end
end
