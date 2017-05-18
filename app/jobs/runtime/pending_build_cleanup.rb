module VCAP::CloudController
  module Jobs
    module Runtime
      class PendingBuildCleanup < VCAP::CloudController::Jobs::CCJob
        ADDITIONAL_EXPIRATION_TIME_IN_SECONDS = 300

        attr_reader :expiration_in_seconds

        def initialize(expiration_in_seconds)
          @expiration_in_seconds = expiration_in_seconds
        end

        def perform
          BuildModel.
            where(state: BuildModel::STAGING_STATE).
            where(updated_at_past_threshold).
            all.
            map { |build| build.fail_to_stage!('StagingTimeExpired') }
        end

        def job_name_in_configuration
          :pending_builds
        end

        def max_attempts
          1
        end

        private

        def updated_at_past_threshold
          Sequel.lit(
            "updated_at < ? - INTERVAL '?' SECOND",
            Sequel::CURRENT_TIMESTAMP,
            expiration_threshold
          )
        end

        def created_at_past_threshold
          Sequel.lit(
            "created_at < ? - INTERVAL '?' SECOND",
            Sequel::CURRENT_TIMESTAMP,
            expiration_threshold
          )
        end

        def expiration_threshold
          expiration_in_seconds + ADDITIONAL_EXPIRATION_TIME_IN_SECONDS
        end
      end
    end
  end
end
