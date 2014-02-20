require "cloud_controller/blobstore/cdn"
require "cloud_controller/dependency_locator"

module VCAP::CloudController
  module Jobs
    module Runtime
      class AppBitsPacker < Struct.new(:app_guid, :uploaded_compressed_path, :fingerprints)
        include VCAP::CloudController::TimedJob

        def perform
          Timeout.timeout max_run_time(:app_bits_packer) do
            app = VCAP::CloudController::App.find(guid: app_guid)
            package_blobstore = CloudController::DependencyLocator.instance.package_blobstore
            global_app_bits_cache = CloudController::DependencyLocator.instance.global_app_bits_cache
            max_droplet_size = VCAP::CloudController::Config.config[:packages][:max_droplet_size] || 512 * 1024 * 1024
            app_bits_packer = AppBitsPackage.new(package_blobstore, global_app_bits_cache, max_droplet_size, VCAP::CloudController::Config.config[:directories][:tmpdir])
            app_bits_packer.create(app, uploaded_compressed_path, CloudController::Blobstore::FingerprintsCollection.new(fingerprints))
          end
        end

        def max_attempts
          1
        end
      end
    end
  end
end
