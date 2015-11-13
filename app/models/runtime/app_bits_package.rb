require 'cloud_controller/blobstore/local_app_bits'
require 'cloud_controller/blobstore/fingerprints_collection'
require 'shellwords'

class AppBitsPackage
  class PackageNotFound < StandardError; end
  class ZipSizeExceeded < StandardError; end
  class InvalidZip < StandardError; end

  attr_reader :package_blobstore, :global_app_bits_cache, :max_package_size, :tmp_dir

  def initialize(package_blobstore, global_app_bits_cache, max_package_size, tmp_dir)
    @package_blobstore = package_blobstore
    @global_app_bits_cache = global_app_bits_cache
    @max_package_size = max_package_size
    @tmp_dir = tmp_dir
  end

  def create(app, uploaded_tmp_compressed_path, fingerprints_in_app_cache)
    CloudController::Blobstore::LocalAppBits.from_compressed_bits(uploaded_tmp_compressed_path, tmp_dir) do |local_app_bits|
      validate_size!(fingerprints_in_app_cache, local_app_bits)

      global_app_bits_cache.cp_r_to_blobstore(local_app_bits.uncompressed_path)

      fingerprints_in_app_cache.each do |local_destination, app_bit_sha, mode|
        global_app_bits_cache.download_from_blobstore(app_bit_sha, File.join(local_app_bits.uncompressed_path, local_destination), mode: mode)
      end

      package = local_app_bits.create_package
      package_blobstore.cp_to_blobstore(package.path, app.guid)
      app.package_hash = Digester.new.digest_file(package)
      app.save
    end
  ensure
    FileUtils.rm_f(uploaded_tmp_compressed_path) if uploaded_tmp_compressed_path
  end

  def create_package_in_blobstore(package_guid, package_path)
    return unless package_path

    package = VCAP::CloudController::PackageModel.find(guid: package_guid)
    raise PackageNotFound if package.nil?

    begin
      raise InvalidZip.new('The zip provided was not valid') unless valid_zip?(package_path)
      raise ZipSizeExceeded if @max_package_size && package_size(package_path) > @max_package_size

      package_blobstore.cp_to_blobstore(package_path, package_guid)

      package.db.transaction do
        package.lock!
        package.package_hash = Digester.new.digest_path(package_path)
        package.state = VCAP::CloudController::PackageModel::READY_STATE
        package.save
      end

      VCAP::CloudController::BitsExpiration.new.expire_packages!(package.app)
    rescue => e
      package.db.transaction do
        package.lock!
        package.state = VCAP::CloudController::PackageModel::FAILED_STATE
        package.error = e.message
        package.save
      end
      raise e
    end
  ensure
    FileUtils.rm_f(package_path) if package_path
  end

  private

  def valid_zip?(package_path)
    command = "unzip -l #{Shellwords.escape(package_path)}"
    r, w = IO.pipe
    pid = Process.spawn(command, out: w, err: [:child, :out])
    w.close
    Process.wait2(pid)
    output = r.read
    r.close
    !output.split("\n").last.match(/^\s*(\d+)/).nil?
  end

  def package_size(package_path)
    zip_info = `unzip -l #{Shellwords.escape(package_path)}`
    zip_info.split("\n").last.match(/^\s*(\d+)/)[1].to_i
  end

  def validate_size!(fingerprints_in_app_cache, local_app_bits)
    return unless max_package_size

    total_size = local_app_bits.storage_size + fingerprints_in_app_cache.storage_size
    if total_size > max_package_size
      raise VCAP::Errors::ApiError.new_from_details('AppPackageInvalid', "Package may not be larger than #{max_package_size} bytes")
    end
  end
end
