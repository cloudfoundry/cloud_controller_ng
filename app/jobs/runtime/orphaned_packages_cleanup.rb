module VCAP::CloudController
  module Jobs
    module Runtime
      class OrphanedPackagesCleanup < VCAP::CloudController::Jobs::CCJob
        attr_accessor :expiration_in_seconds

        PACKAGE_GUID = /^[a-z0-9]{2}\/[a-z0-9]{2}\/([a-z0-9]{8}-([a-z0-9]{4}-){3}[a-z0-9]{12})/

        def initialize(cleanup_after_days)
          @cleanup_after_days = cleanup_after_days.days
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info('Looking for orphaned packages in blobstore')

          packages = PackageModel.select_map(:guid)
          apps = App.select_map(:guid)

          blobstore = CloudController::DependencyLocator.instance.package_blobstore
          blobstore.files.each do |file|
            next unless file.last_modified < DateTime.now - @cleanup_after_days
            guid = file.key.match(PACKAGE_GUID).captures.first
            next if packages.include?(guid)
            next if apps.include?(guid)

            logger.debug("Cleaning orphaned package: #{file.key}")
            file.destroy
          end
        end

        def job_name_in_configuration
          :orphaned_packages_cleanup
        end

        def max_attempts
          1
        end
      end
    end
  end
end
