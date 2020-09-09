require 'cloud_controller/blobstore/fingerprints_collection'
require 'cloud_controller/app_packager'
require 'cloud_controller/packager/shared_bits_packer'

module CloudController
  module Packager
    class LocalBitsPacker
      include Packager::SharedBitsPacker

      def send_package_to_blobstore(blobstore_key, uploaded_package_zip, cached_files_fingerprints)
        tmp_dir = VCAP::CloudController::Config.config.get(:directories, :tmpdir)
        Dir.mktmpdir('local_bits_packer', tmp_dir) do |root_path|
          complete_package_path = match_resources_and_validate_package(root_path, uploaded_package_zip, cached_files_fingerprints)

          package_blobstore.cp_to_blobstore(complete_package_path, blobstore_key)

          {
            sha1:   Digester.new.digest_path(complete_package_path),
            sha256: Digester.new(algorithm: Digest::SHA256).digest_path(complete_package_path),
          }
        end
      end

      private

      def package_blobstore
        CloudController::DependencyLocator.instance.package_blobstore
      end
    end
  end
end
