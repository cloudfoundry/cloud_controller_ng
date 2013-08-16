require "workers/runtime/app_bits_packer"
require "cloud_controller/blob_store/cdn"

class AppBitsPackerJob < Struct.new(:app_guid, :uploaded_compressed_path, :fingerprints)
  def perform
    app = VCAP::CloudController::Models::App.find(guid: app_guid)

    package_cdn = Cdn.new(Settings.resource_pool.cdn.uri) if Settings.resource_pool.cdn

    package_blob_store = BlobStore.new(
      Settings.resource_pool.fog_connection,
      Settings.resource_pool.resource_directory_key || "cc-resources",
      package_cdn)


    app_bit_cdn = Cdn.new(Settings.packages.cdn.uri) if Settings.packages.cdn
    app_bit_cache = BlobStore.new(
      Settings.packages.fog_connection,
      Settings.packages.app_package_directory_key || "cc-app-packages",
      app_bit_cdn)

    app_bits_packer = AppBitsPacker.new(package_blob_store, app_bit_cache)
    app_bits_packer.perform(app, uploaded_compressed_path, FingerprintsCollection.new(fingerprints))
  end
end