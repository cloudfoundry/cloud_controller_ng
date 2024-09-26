require 'cloud_controller/blobstore/fingerprints_collection'
require 'cloud_controller/app_packager'
require 'cloud_controller/packager/shared_bits_packer'

module CloudController
  module Packager
    class ConflictError < StandardError
    end

    class LocalBitsPacker
      include Packager::SharedBitsPacker

      def send_package_to_blobstore(blobstore_key, uploaded_package_zip, cached_files_fingerprints)
        tmp_dir = VCAP::CloudController::Config.config.get(:directories, :tmpdir)
        local_bits_packer_path = File.join(tmp_dir, "local_bits_packer-#{blobstore_key}")

        if Dir.exist?(local_bits_packer_path)
          raise ConflictError.new("Found a leftover directory that might be from the previous worker's unfinished job: #{local_bits_packer_path}")
        end

        Dir.mkdir(local_bits_packer_path)

        begin
          complete_package_path = match_resources_and_validate_package(local_bits_packer_path, uploaded_package_zip, cached_files_fingerprints)

          package_blobstore.cp_to_blobstore(complete_package_path, blobstore_key)

          {
            sha1: Digester.new.digest_path(complete_package_path),
            sha256: Digester.new(algorithm: OpenSSL::Digest::SHA256).digest_path(complete_package_path)
          }
        ensure
          FileUtils.remove_dir(local_bits_packer_path)
        end
      end

      private

      def package_blobstore
        CloudController::DependencyLocator.instance.package_blobstore
      end
    end
  end
end
