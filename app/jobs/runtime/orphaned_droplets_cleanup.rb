module VCAP::CloudController
  module Jobs
    module Runtime
      class OrphanedDropletsCleanup < VCAP::CloudController::Jobs::CCJob
        attr_accessor :expiration_in_seconds

        DROPLET_GUID = %r(^[a-z0-9]{2}/[a-z0-9]{2}/([a-z0-9]{8}-([a-z0-9]{4}-){3}[a-z0-9]{12})/[a-z0-9]{40}$)
        def initialize(cutoff_age_in_days)
          @cutoff_age_in_days = cutoff_age_in_days
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info('Looking for orphaned droplets in blobstore')

          blobstore.files.each do |file|
            next unless file.last_modified < DateTime.now - @cutoff_age_in_days
            match = file.key.match(DROPLET_GUID)
            next unless match
            guid = match.captures.first
            next if droplets.include?(guid)
            next if apps.include?(guid)

            logger.debug("Cleaning orphaned droplet: #{file.key}")
            file.destroy
          end
        end

        def job_name_in_configuration
          :orphaned_droplets_cleanup
        end

        def max_attempts
          1
        end

        private

        def apps
          @apps ||= App.select_map(:guid)
        end

        def droplets
          @droplets ||= DropletModel.select_map(:guid)
        end

        def blobstore
          CloudController::DependencyLocator.instance.droplet_blobstore
        end
      end
    end
  end
end
