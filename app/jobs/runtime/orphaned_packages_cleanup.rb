module VCAP::CloudController
  module Jobs
    module Runtime
      class OrphanedPackagesCleanup < VCAP::CloudController::Jobs::CCJob
        attr_accessor :expiration_in_seconds

        PACKAGE_GUID = %r(^[a-z0-9]{2}/[a-z0-9]{2}/([a-z0-9]{8}-([a-z0-9]{4}-){3}[a-z0-9]{12})$)

        def initialize(cutoff_age_in_days)
          @cutoff_age_in_days = cutoff_age_in_days
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info('Looking for orphaned packages in blobstore')

          blobstore.files.each do |file|
            next unless file.last_modified < DateTime.now - @cutoff_age_in_days
            match = file.key.match(PACKAGE_GUID)
            next unless match
            guid = match.captures.first
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

        private

        def blobstore
          CloudController::DependencyLocator.instance.package_blobstore
        end

        def packages
          @packages ||= PackageModel.select_map(:guid)
        end

        def apps
          @apps ||= App.select_map(:guid)
        end
      end
    end
  end
end
