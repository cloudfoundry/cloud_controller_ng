require "workers/runtime/app_bits_packer"
require "cloud_controller/blob_store/cdn"
require "factories/blob_store_factory"

class AppBitsPackerJob < Struct.new(:app_guid, :uploaded_compressed_path, :fingerprints)
  def perform
    app = VCAP::CloudController::Models::App.find(guid: app_guid)
    package_blob_store = BlobStoreFactory.get_package_blob_store
    app_bit_cache = BlobStoreFactory.get_app_bit_cache
    app_bits_packer = AppBitsPacker.new(package_blob_store, app_bit_cache)
    app_bits_packer.perform(app, uploaded_compressed_path, FingerprintsCollection.new(fingerprints))
  end
end