require "cloud_controller/blob_store/local_app_bits"
require "rails_config"
require "cloud_controller/blob_store/fingerprints_collection"

class AppBitsPacker
  attr_reader :package_blob_store, :app_bit_cache

  def initialize(package_blob_store, app_bit_cache)
    @package_blob_store = package_blob_store
    @app_bit_cache = app_bit_cache
  end

  def perform(app, uploaded_compressed_bits, fingerprints_in_app_cache)
    LocalAppBits.from_compressed_bits(uploaded_compressed_bits) do |local_app_bits|
      validate_size!(fingerprints_in_app_cache, local_app_bits)

      app_bit_cache.cp_r_from_local(local_app_bits.root_path)

      fingerprints_in_app_cache.each do |local_destination, app_bit_sha|
        app_bit_cache.cp_to_local(app_bit_sha, File.join(local_app_bits.root_path, local_destination))
      end

      package = local_app_bits.create_package
      package_blob_store.cp_from_local(package.path, app.guid)
      app.package_hash = package.hexdigest
      app.save
    end
  end

  private

  def validate_size!(fingerprints_in_app_cache, local_app_bits)
    total_size = local_app_bits.storage_size + fingerprints_in_app_cache.storage_size
    max_allowed_package_size = Settings.packages.max_droplet_size || 512 * 1024 * 1024
    if total_size > max_allowed_package_size
      raise VCAP::Errors::AppPackageInvalid, "Package may not be larger than #{Settings.packages.max_droplet_size} bytes"
    end
  end
end