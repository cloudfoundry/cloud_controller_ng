require 'cloud_controller/blobstore/local_app_bits'
require 'cloud_controller/blobstore/fingerprints_collection'
require 'shellwords'

class AppBitsPackage
  class PackageNotFound < StandardError; end

  def create_package_in_blobstore(package_guid, package_path, cached_files_fingerprints)
    package = VCAP::CloudController::PackageModel.find(guid: package_guid)
    raise PackageNotFound if package.nil?

    begin
      CloudController::Blobstore::LocalAppBits.from_compressed_bits(package_path, tmp_dir) do |local_app_bits|
        validate_size!(cached_files_fingerprints, local_app_bits)

        global_app_bits_cache.cp_r_to_blobstore(local_app_bits.uncompressed_path)

        cached_files_fingerprints.each do |local_destination, file_sha, mode|
          global_app_bits_cache.download_from_blobstore(file_sha, File.join(local_app_bits.uncompressed_path, local_destination), mode: mode)
        end

        rezipped_package = local_app_bits.create_package
        package_blobstore.cp_to_blobstore(rezipped_package.path, package_guid)
        package.succeed_upload!(Digester.new.digest_path(rezipped_package))
      end

      VCAP::CloudController::BitsExpiration.new.expire_packages!(package.app)
    rescue => e
      package.fail_upload!(e.message)
      raise e
    end
  ensure
    FileUtils.rm_f(package_path) if package_path
  end

  private

  def validate_size!(fingerprints_in_app_cache, local_app_bits)
    return unless max_package_size

    total_size = local_app_bits.storage_size + fingerprints_in_app_cache.storage_size
    if total_size > max_package_size
      raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid', "Package may not be larger than #{max_package_size} bytes")
    end
  end

  def tmp_dir
    @tmp_dir ||= VCAP::CloudController::Config.config[:directories][:tmpdir]
  end

  def package_blobstore
    @package_blobstore ||= CloudController::DependencyLocator.instance.package_blobstore
  end

  def global_app_bits_cache
    @global_app_bits_cache ||= CloudController::DependencyLocator.instance.global_app_bits_cache
  end

  def max_package_size
    @max_package_size ||= VCAP::CloudController::Config.config[:packages][:max_package_size] || 512 * 1024 * 1024
  end
end
