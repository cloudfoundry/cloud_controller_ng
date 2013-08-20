class BlobStoreFactory
  def self.get_package_blob_store
    package_cdn = Cdn.new(Settings.packages.cdn.uri) if Settings.packages.cdn
    BlobStore.new(Settings.packages.fog_connection, Settings.packages.app_package_directory_key, package_cdn)
  end

  def self.get_app_bit_cache
    app_bit_cdn = Cdn.new(Settings.resource_pool.cdn.uri) if Settings.resource_pool.cdn
    BlobStore.new(Settings.resource_pool.fog_connection, Settings.resource_pool.resource_directory_key, app_bit_cdn)
  end
end