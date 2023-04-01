require 'cloud_controller/blobstore/base_client'
require 'cloud_controller/blobstore/credhub_blob'

module CloudController
  module Blobstore
    class CredhubClient < BaseClient
      def initialize(credhub_client:, directory_key:, root_dir:)
        @credhub_client = credhub_client
        @directory_key = directory_key
        @root_dir = root_dir
        @min_size = 65536
        @max_size = 536870912
      end

      def local?
        false
      end

      def exists?(key)
        @credhub_client.credential_exists?(credhub_path(key))
      end

      def download_from_blobstore(source_key, destination_path, mode: nil)
        FileUtils.mkdir_p(File.dirname(destination_path))

        File.open(destination_path, 'wb') do |file|
          file.write decode_file(@credhub_client.get_chunked_credential_by_name(credhub_path(source_key)))
          file.chmod(mode) if mode
        end
      end

      def ensure_bucket_exists
      end

      def cp_to_blobstore(source_path, destination_key)
        File.open(source_path) do |file|
          @credhub_client.save_credential(credhub_path(destination_key), encode_file(file.read))
        end
      end

      def delete_all_in_path(path)
        full_path = credhub_path(path)
        @credhub_client.find_credentials_in_path(full_path).each do |entry|
          @credhub_client.delete_credential(entry)
        end
      end

      def blob(key)
        return CredhubBlob.new(key: credhub_path(key))
      end
      def delete_blob(blob)
        @credhub_client.delete_credential(credhub_path(blob.key))
      end

      private

      def credhub_path(key)
        "/cloud_controller_blobs/#{@directory_key}/#{key}"
      end

      def encode_file(data)
        Base64.strict_encode64(data.force_encoding('BINARY'))
      end

      def decode_file(data)
        Base64.strict_decode64(data).force_encoding('BINARY')
      end

      def within_limits?(size)
        true
      end
    end
  end
end
