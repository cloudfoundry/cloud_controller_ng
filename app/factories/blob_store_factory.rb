class BlobStoreFactory
  def self.get_package_blob_store
    package_cdn = Cdn.new(VCAP::CloudController::Config.config[:packages][:cdn][:uri]) if VCAP::CloudController::Config.config[:packages][:cdn]
    BlobStore.new(VCAP::CloudController::Config.config[:packages][:fog_connection], VCAP::CloudController::Config.config[:packages][:app_package_directory_key], package_cdn)
  end

  def self.get_app_bit_cache
    app_bit_cdn = Cdn.new(VCAP::CloudController::Config.config[:resource_pool][:cdn][:uri]) if VCAP::CloudController::Config.config[:resource_pool][:cdn]
    BlobStore.new(VCAP::CloudController::Config.config[:resource_pool][:fog_connection], VCAP::CloudController::Config.config[:resource_pool][:resource_directory_key], app_bit_cdn)
  end
end