require 'cloud_controller/blobstore/local_app_bits'
require 'cloud_controller/blobstore/fingerprints_collection'
require 'shellwords'

module CloudController
  module Packager
    class LocalBitsPacker
      def send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
        fingerprints_collection = CloudController::Blobstore::FingerprintsCollection.new(cached_files_fingerprints)

        CloudController::Blobstore::LocalAppBits.from_compressed_bits(uploaded_files_path, tmp_dir) do |local_app_bits|
          validate_size!(fingerprints_collection, local_app_bits)

          global_app_bits_cache.cp_r_to_blobstore(local_app_bits.uncompressed_path)

          fingerprints_collection.each do |local_destination, file_sha, mode|
            global_app_bits_cache.download_from_blobstore(file_sha, File.join(local_app_bits.uncompressed_path, local_destination), mode: mode)
          end

          rezipped_package = local_app_bits.create_package
          package_blobstore.cp_to_blobstore(rezipped_package.path, blobstore_key)
          Digester.new.digest_path(rezipped_package)
        end
      end

      private

      def validate_size!(fingerprints_in_app_cache, local_app_bits)
        return unless max_package_size

        total_size = local_app_bits.storage_size + fingerprints_in_app_cache.storage_size
        if total_size > max_package_size
          raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid', "Package may not be larger than #{max_package_size} bytes")
        end
      end

      def tmp_dir
        @tmp_dir ||= VCAP::CloudController::Config.config[:directories][:tmpdir]
      end

      def package_blobstore
        @package_blobstore ||= CloudController::DependencyLocator.instance.package_blobstore
      end

      def global_app_bits_cache
        @global_app_bits_cache ||= CloudController::DependencyLocator.instance.global_app_bits_cache
      end

      def max_package_size
        @max_package_size ||= VCAP::CloudController::Config.config[:packages][:max_package_size] || 512 * 1024 * 1024
      end
    end
  end
end
