require "cloud_controller/resource_pool"

class AppPackageWorker
  attr_reader :app_guid, :zip_path, :fingerprints

  def initialize(app_guid, zip_path, fingerprints_already_in_app_cache)
    @app_guid = app_guid
    @zip_path = zip_path
    @fingerprints = FingerprintsCollection.new(fingerprints_already_in_app_cache)
  end

  def perform
    LocalAppBits.from_zip_of_new_files(zip_path) do |local_app_bits|
      app_bit_cache.cp_r_from_local(local_app_bits.root_path)

      fingerprints.each_sha do |sha1|
        app_bit_cache.cp_to_local(sha1, local_app_bits.root_path)
      end

      package_path = local_app_bits.create_package
      package_blob_store.cp_from_local(package_path, app_guid)
    end
  end

  private

  def package_blob_store
    @package_blob_store ||= BlobStore.new({}, "")
  end

  def app_bit_cache
    @app_bit_cache ||= BlobStore.new({}, "")
  end
end