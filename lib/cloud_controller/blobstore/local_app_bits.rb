require "cloud_controller/safe_zipper"
require "ext/file"

module CloudController
  module Blobstore
    class LocalAppBits
      PACKAGE_NAME = "package.zip".freeze
      UNCOMPRESSED_DIR = "uncompressed"

      def self.from_compressed_bits(compressed_bits_path, tmp_dir, &block)
        Dir.mktmpdir("safezipper", tmp_dir) do |root_path|
          unzip_path = File.join(root_path, UNCOMPRESSED_DIR)
          FileUtils.mkdir(unzip_path)
          storage_size = 0
          if compressed_bits_path && File.exists?(compressed_bits_path)
            storage_size = SafeZipper.unzip(compressed_bits_path, unzip_path)
          end
          block.yield new(root_path, storage_size)
        end
      end

      attr_reader :uncompressed_path, :storage_size

      def initialize(root_path, storage_size)
        @root_path = root_path
        @uncompressed_path = File.join(root_path, UNCOMPRESSED_DIR)
        @storage_size = storage_size
      end

      def create_package
        destination = File.join(@root_path, PACKAGE_NAME)
        SafeZipper.zip(uncompressed_path, destination)
        File.new(destination)
      end
    end
  end
end
