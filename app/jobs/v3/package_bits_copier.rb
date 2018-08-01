module VCAP::CloudController
  module Jobs
    module V3
      class PackageBitsCopier < VCAP::CloudController::Jobs::CCJob
        def initialize(src_package_guid, dest_package_guid)
          @src_package_guid  = src_package_guid
          @dest_package_guid = dest_package_guid
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info("Copying the package bits from package '#{@src_package_guid}' to package '#{@dest_package_guid}'")

          dest_package = VCAP::CloudController::PackageModel.find(guid: @dest_package_guid)
          raise 'destination package does not exist' unless dest_package
          src_package = VCAP::CloudController::PackageModel.find(guid: @src_package_guid)
          raise 'source package does not exist' unless src_package

          CloudController::DependencyLocator.instance.package_blobstore.cp_file_between_keys(@src_package_guid, @dest_package_guid)

          dest_package.succeed_upload!(src_package.package_hash)

        rescue => e
          dest_package.fail_upload!("failed to copy - #{e.message}") if dest_package
          raise
        end

        def job_name_in_configuration
          :package_bits_copier
        end

        def max_attempts
          1
        end
      end
    end
  end
end
