module VCAP::CloudController
  module V2
    class AppStage
      def initialize(stagers:)
        @stagers = stagers
      end

      def stage(process)
        @stagers.validate_process(process)

        message = BuildCreateMessage.new({
          staging_memory_in_mb: process.memory,
          staging_disk_in_mb:   process.disk_quota
        })

        lifecycle = LifecycleProvider.provide(process.latest_package, message)

        # we use non quota validating calculators in v2 b/c app instances are stopped in order for staging to occur
        # so the quota validation that runs when an app is started is sufficient, we do not need to run extra validations
        # for the staging process
        build_creator = BuildCreate.new(memory_limit_calculator: NonQuotaValidatingStagingMemoryCalculator.new)

        build_creator.create_and_stage_without_event(
          package:             process.latest_package,
          lifecycle:           lifecycle,
          start_after_staging: true
        )

        process.last_stager_response = build_creator.staging_response
      rescue Diego::Runner::CannotCommunicateWithDiegoError => e
        logger.error("failed communicating with diego backend: #{e.message}")
      rescue BuildCreate::SpaceQuotaExceeded => e
        raise CloudController::Errors::ApiError.new_from_details('SpaceQuotaMemoryLimitExceeded', e.message)
      rescue BuildCreate::OrgQuotaExceeded => e
        raise CloudController::Errors::ApiError.new_from_details('AppMemoryQuotaExceeded', e.message)
      rescue BuildCreate::DiskLimitExceeded
        raise CloudController::Errors::ApiError.new_from_details('AppInvalid', 'too much disk requested')
      rescue BuildCreate::BuildError => e
        raise CloudController::Errors::ApiError.new_from_details('AppInvalid', e.message)
      end
    end
  end
end
