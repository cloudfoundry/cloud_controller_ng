require 'jobs/kubernetes/registry_delete'
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

          if VCAP::CloudController::Config.config.package_image_registry_configured?
            VCAP::CloudController::Jobs::Kubernetes::RegistryDelete.new(package.bits_image_reference).perform
          else
            BlobstoreDelete.new(package_guid, :package_blobstore).perform
          end
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
      end
    end
  end
end
