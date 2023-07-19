require 'jobs/runtime/blobstore_delete'

module VCAP::CloudController
  module Jobs
    module Runtime
      class DeleteExpiredPackageBlob < VCAP::CloudController::Jobs::CCJob
        attr_reader :package_guid

        def initialize(package_guid)
          @package_guid = package_guid
        end

        def perform
          logger.info("Deleting expired package blob for package: #{package_guid}")

          package = PackageModel.find(guid: package_guid)
          return unless package

          create_package_source_deletion_job(package)&.perform
          package.update(package_hash: nil, sha256_checksum: nil)
        end

        def job_name_in_configuration
          :delete_expired_package_blob
        end

        def max_attempts
          1
        end

        def logger
          @logger ||= Steno.logger('cc.background')
        end

        private

        def package_registry_configured?
          VCAP::CloudController::Config.config.package_image_registry_configured?
        end

        def create_package_source_deletion_job(package)
          return Jobs::Runtime::BlobstoreDelete.new(package.guid, :package_blobstore) unless package_registry_configured?

          nil
        end
      end
    end
  end
end
