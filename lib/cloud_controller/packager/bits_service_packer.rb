require 'cloud_controller/dependency_locator'

module CloudController
  module Packager
    class BitsServicePacker
      def send_package_to_blobstore(blobstore_key, uploaded_package_zip, cached_files_fingerprints)
        bundle_response = resource_pool.bundles(cached_files_fingerprints.to_json, uploaded_package_zip)
        package = create_temp_file_with_content(bundle_response.body)
        package_blobstore.cp_to_blobstore(package.path, blobstore_key)
        {
          sha1: Digester.new.digest_file(package),
          sha256: Digester.new(algorithm: Digest::SHA256).digest_file(package),
        }
      rescue => e
        raise CloudController::Errors::ApiError.new_from_details('BitsServiceError', e.message) if e.is_a?(BitsService::Errors::Error)
        raise
      end

      private

      def create_temp_file_with_content(content)
        package = Tempfile.new('package.zip')
        package.binmode
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
