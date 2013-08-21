require "cloud_controller/blob_store/local_app_bits"
require "cloud_controller/blob_store/fingerprints_collection"

class AppBitsPacker
  attr_reader :package_blob_store, :app_bit_cache, :max_droplet_size, :tmp_dir

  def initialize(package_blob_store, app_bit_cache, max_droplet_size, tmp_dir)
    @package_blob_store = package_blob_store
    @app_bit_cache = app_bit_cache
    @max_droplet_size = max_droplet_size
    @tmp_dir = tmp_dir
  end

  def perform(app, uploaded_compressed_path, fingerprints_in_app_cache)
    LocalAppBits.from_compressed_bits(uploaded_compressed_path, tmp_dir) do |local_app_bits|
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
    return unless max_droplet_size

    total_size = local_app_bits.storage_size + fingerprints_in_app_cache.storage_size
    if total_size > max_droplet_size
      raise VCAP::Errors::AppPackageInvalid, "Package may not be larger than #{max_droplet_size} bytes"
    end
  end
end