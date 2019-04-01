require 'cloud_controller/dependency_locator'

module CloudController
  module Packager
    class BitsServicePacker
      def send_package_to_blobstore(blobstore_key, uploaded_package_zip, cached_files_fingerprints)
        CloudController::DependencyLocator.instance.package_blobstore.
          cp_to_blobstore(uploaded_package_zip, blobstore_key, resources: cached_files_fingerprints)
      rescue => e
        raise CloudController::Errors::ApiError.new_from_details('BitsServiceError', e.message) if e.is_a?(BitsService::Errors::Error)

        raise
      end
    end
  end
end
