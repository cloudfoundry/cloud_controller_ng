require 'cloud_controller/dependency_locator'

module CloudController
  module Packager
    class BitsServicePacker
      def send_package_to_blobstore(blobstore_key, uploaded_files_path, cached_files_fingerprints)
        fingerprints_from_upload = upload_missing_entries(uploaded_files_path)
        generate_package(cached_files_fingerprints | fingerprints_from_upload, 'package.zip', blobstore_key)
      rescue => e
        raise CloudController::Errors::ApiError.new_from_details('BitsServiceError', e.message) if e.is_a?(BitsService::Errors::Error)
        raise
      end

      private

      def upload_missing_entries(zip_of_files_not_in_blobstore_path)
        if zip_of_files_not_in_blobstore_path.to_s != ''
          entries_response = resource_pool.upload_entries(zip_of_files_not_in_blobstore_path)
          JSON.parse(entries_response.body)
        else
          []
        end
      end

      def generate_package(fingerprints, package_filename, blobstore_key)
        bundle_response = resource_pool.bundles(fingerprints.to_json)
        package         = create_temp_file_with_content(package_filename, bundle_response.body)
        package_blobstore.cp_to_blobstore(package.path, blobstore_key)
        {
          sha1: Digester.new.digest_file(package),
          sha256: Digester.new(algorithm: Digest::SHA256).digest_file(package),
        }
      end

      def create_temp_file_with_content(filename, content)
        package = Tempfile.new(filename).binmode
        package.write(content)
        package.close
        package
      end

      def resource_pool
        CloudController::DependencyLocator.instance.bits_service_resource_pool
      end

      def package_blobstore
        CloudController::DependencyLocator.instance.package_blobstore
      end
    end
  end
end
