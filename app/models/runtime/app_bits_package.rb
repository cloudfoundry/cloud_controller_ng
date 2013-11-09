require "cloud_controller/blobstore/local_app_bits"
require "cloud_controller/blobstore/fingerprints_collection"

class AppBitsPackage
  attr_reader :package_blobstore, :global_app_bits_cache, :max_droplet_size, :tmp_dir

  def initialize(package_blobstore, global_app_bits_cache, max_droplet_size, tmp_dir)
    @package_blobstore = package_blobstore
    @global_app_bits_cache = global_app_bits_cache
    @max_droplet_size = max_droplet_size
    @tmp_dir = tmp_dir
  end

  def create(app, uploaded_tmp_compressed_path, fingerprints_in_app_cache)
    LocalAppBits.from_compressed_bits(uploaded_tmp_compressed_path, tmp_dir) do |local_app_bits|
      validate_size!(fingerprints_in_app_cache, local_app_bits)

      global_app_bits_cache.cp_r_to_blobstore(local_app_bits.uncompressed_path)

      fingerprints_in_app_cache.each do |local_destination, app_bit_sha|
        global_app_bits_cache.download_from_blobstore(app_bit_sha, File.join(local_app_bits.uncompressed_path, local_destination))
      end

      package = local_app_bits.create_package
      package_blobstore.cp_to_blobstore(package.path, app.guid)
      app.package_hash = package.hexdigest
      app.save
    end
  ensure
    FileUtils.rm_f(uploaded_tmp_compressed_path) if uploaded_tmp_compressed_path
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
