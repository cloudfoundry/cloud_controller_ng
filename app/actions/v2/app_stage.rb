module VCAP::CloudController
  module V2
    class AppStage
      def initialize(stagers:)
        @stagers = stagers
      end

      def stage(app)
        @stagers.validate_app(app)

        message = DropletCreateMessage.new({
          staging_memory_in_mb: app.memory,
          staging_disk_in_mb:   app.disk_quota
        })

        lifecycle = LifecycleProvider.provide(app.latest_package, message)

        # we use non quota validating calculators in v2 b/c app instances are stopped in order for staging to occur
        # so the quota validation that runs when an app is started is sufficient, we do not need to run extra validations
        # for the staging process
        droplet_creator = DropletCreate.new(memory_limit_calculator: NonQuotaValidatingStagingMemoryCalculator.new)

        droplet_creator.create_and_stage_without_event(
          package:             app.latest_package,
          lifecycle:           lifecycle,
          message:             message,
          start_after_staging: true
        )

        app.last_stager_response = droplet_creator.staging_response
      rescue Diego::Runner::CannotCommunicateWithDiegoError => e
        logger.error("failed communicating with diego backend: #{e.message}")
      rescue DropletCreate::SpaceQuotaExceeded => e
        raise CloudController::Errors::ApiError.new_from_details('SpaceQuotaMemoryLimitExceeded', e.message)
      rescue DropletCreate::OrgQuotaExceeded => e
        raise CloudController::Errors::ApiError.new_from_details('AppMemoryQuotaExceeded', e.message)
      rescue DropletCreate::DiskLimitExceeded
        raise CloudController::Errors::ApiError.new_from_details('AppInvalid', 'too much disk requested')
      rescue DropletCreate::DropletError => e
        raise CloudController::Errors::ApiError.new_from_details('AppInvalid', e.message)
      end
    end
  end
end
