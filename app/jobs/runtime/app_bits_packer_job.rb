require "jobs/runtime/app_bits_packer"
require "cloud_controller/blobstore/cdn"
require "cloud_controller/dependency_locator"

class AppBitsPackerJob < Struct.new(:app_guid, :uploaded_compressed_path, :fingerprints)
  def perform
    app = VCAP::CloudController::App.find(guid: app_guid)
    package_blobstore = CloudController::DependencyLocator.instance.package_blobstore
    global_app_bits_cache = CloudController::DependencyLocator.instance.global_app_bits_cache
    max_droplet_size = VCAP::CloudController::Config.config[:packages][:max_droplet_size] || 512 * 1024 * 1024
    app_bits_packer = AppBitsPacker.new(package_blobstore, global_app_bits_cache, max_droplet_size, VCAP::CloudController::Config.config[:directories][:tmpdir])
    app_bits_packer.perform(app, uploaded_compressed_path, FingerprintsCollection.new(fingerprints))
  end

  def max_attempts
    1
  end
end
