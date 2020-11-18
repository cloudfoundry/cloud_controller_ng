require 'shellwords'

module CloudController
  module Packager
    module SharedBitsPacker
      private

      def package_zip_exists?(package_zip)
        package_zip && File.exist?(package_zip)
      end

      def validate_size!(app_packager)
        return unless max_package_size

        if app_packager.size > max_package_size
          raise CloudController::Errors::ApiError.new_from_details('AppPackageInvalid', "Package may not be larger than #{max_package_size} bytes")
        end
      end

      def copy_uploaded_package(uploaded_package_zip, app_packager)
        FileUtils.chmod('u+w', uploaded_package_zip)
        FileUtils.cp(uploaded_package_zip, app_packager.path)
      end

      def populate_resource_cache(app_packager, app_contents_path)
        FileUtils.mkdir(app_contents_path)
        app_packager.unzip(app_contents_path)

        remove_symlinks(app_contents_path)

        global_app_bits_cache.cp_r_to_blobstore(app_contents_path)
      end

      def remove_symlinks(app_contents_path)
        Find.find(app_contents_path) do |path|
          File.delete(path) if File.symlink?(path)
        end
      end

      def append_matched_resources(app_packager, cached_files_fingerprints, root_path)
        matched_resources = CloudController::Blobstore::FingerprintsCollection.new(cached_files_fingerprints, root_path)
        cached_resources_dir = File.join(root_path, 'cached_resources_dir')

        FileUtils.mkdir(cached_resources_dir)
        matched_resources.each do |local_destination, file_sha, mode|
          global_app_bits_cache.download_from_blobstore(file_sha, File.join(cached_resources_dir, local_destination), mode: mode)
        end
        app_packager.append_dir_contents(cached_resources_dir)
      end

      def match_resources_and_validate_package(root_path, uploaded_package_zip, cached_files_fingerprints)
        app_packager = AppPackager.new(File.join(root_path, 'copied_app_package.zip'))
        app_contents_path = File.join(root_path, 'application_contents')

        if package_zip_exists?(uploaded_package_zip)
          copy_uploaded_package(uploaded_package_zip, app_packager)
          validate_size!(app_packager)
          populate_resource_cache(app_packager, app_contents_path) unless VCAP::CloudController::FeatureFlag.disabled?(:resource_matching)
        end

        append_matched_resources(app_packager, cached_files_fingerprints, root_path)

        validate_size!(app_packager)
        app_packager.fix_subdir_permissions(root_path, app_contents_path)
        app_packager.path
      end

      def max_package_size
        VCAP::CloudController::Config.config.get(:packages, :max_package_size)
      end

      def global_app_bits_cache
        CloudController::DependencyLocator.instance.global_app_bits_cache
      end
    end
  end
end
