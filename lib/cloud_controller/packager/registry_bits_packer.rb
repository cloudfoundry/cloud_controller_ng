require 'registry_buddy/client'
require 'cloud_controller/blobstore/fingerprints_collection'
require 'cloud_controller/app_packager'
require 'cloud_controller/packager/shared_bits_packer'

module CloudController
  module Packager
    class RegistryBitsPacker
      include Packager::SharedBitsPacker

      def send_package_to_blobstore(package_guid, uploaded_package_zip, cached_files_fingerprints)
        Dir.mktmpdir('registry_bits_packer', packages_tmp_dir) do |root_path|
          complete_package_path = match_resources_and_validate_package(root_path, uploaded_package_zip, cached_files_fingerprints)
          client = CloudController::DependencyLocator.instance.registry_buddy_client

          registry = VCAP::CloudController::Config.config.get(:packages, :image_registry, :base_path)
          response = client.post_package(package_guid, complete_package_path, registry)
          { sha1: nil, sha256: response['hash']['hex'] }
        end
      end

      private

      def packages_tmp_dir
        File.join(VCAP::CloudController::Config.config.get(:directories, :tmpdir), '/packages/')
      end
    end
  end
end
