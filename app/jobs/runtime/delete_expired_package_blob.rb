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
          BlobstoreDelete.new(package_guid, :package_blobstore).perform
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
