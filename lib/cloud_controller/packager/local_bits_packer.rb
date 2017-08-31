require 'cloud_controller/blobstore/fingerprints_collection'
require 'shellwords'
require 'cloud_controller/app_packager'

module CloudController
  module Packager
    class LocalBitsPacker
      def send_package_to_blobstore(blobstore_key, uploaded_package_zip, cached_files_fingerprints)
        matched_resources = CloudController::Blobstore::FingerprintsCollection.new(cached_files_fingerprints)

        Dir.mktmpdir('local_bits_packer', tmp_dir) do |root_path|
          app_package_zip = File.join(root_path, 'copied_app_package.zip')
          app_packager = AppPackager.new(app_package_zip)

          if package_zip_exists?(uploaded_package_zip)
            FileUtils.chmod('u+w', uploaded_package_zip)
            FileUtils.cp(uploaded_package_zip, app_package_zip)
            populate_resource_cache(app_packager, root_path)
          end

          append_matched_resources(app_packager, matched_resources, root_path)

          app_packager.fix_subdir_permissions
          validate_size!(app_packager)

          package_blobstore.cp_to_blobstore(app_package_zip, blobstore_key)

          {
            sha1:   Digester.new.digest_path(app_package_zip),
            sha256: Digester.new(algorithm: Digest::SHA256).digest_path(app_package_zip),
          }
        end
      end

      private

      def package_zip_exists?(package_zip)
        package_zip && File.exist?(package_zip)
      end

      def populate_resource_cache(app_packager, root_path)
        app_contents_path = File.join(root_path, 'application_contents')
        FileUtils.mkdir(app_contents_path)
        app_packager.unzip(app_contents_path)
        global_app_bits_cache.cp_r_to_blobstore(app_contents_path)
      end

      def append_matched_resources(app_packager, matched_resources, root_path)
        cached_resources_dir = File.join(root_path, 'cached_resources_dir')
        FileUtils.mkdir(cached_resources_dir)
        matched_resources.each do |local_destination, file_sha, mode|
          global_app_bits_cache.download_from_blobstore(file_sha, File.join(cached_resources_dir, local_destination), mode: mode)
        end
        app_packager.append_dir_contents(cached_resources_dir)
      end

      def validate_size!(app_packager)
        return unless max_package_size

        if app_packager.size > max_package_size
          raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid', "Package may not be larger than #{max_package_size} bytes")
        end
      end

      def tmp_dir
        @tmp_dir ||= VCAP::CloudController::Config.config.get(:directories, :tmpdir)
      end

      def package_blobstore
        @package_blobstore ||= CloudController::DependencyLocator.instance.package_blobstore
      end

      def global_app_bits_cache
        @global_app_bits_cache ||= CloudController::DependencyLocator.instance.global_app_bits_cache
      end

      def max_package_size
        @max_package_size ||= VCAP::CloudController::Config.config.get(:packages, :max_package_size) || 512 * 1024 * 1024
      end
    end
  end
end
