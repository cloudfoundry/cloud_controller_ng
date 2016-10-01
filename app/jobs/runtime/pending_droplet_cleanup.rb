module VCAP::CloudController
  module Jobs
    module Runtime
      class PendingDropletCleanup < VCAP::CloudController::Jobs::CCJob
        ADDITIONAL_EXPIRATION_TIME_IN_SECONDS = 300

        attr_reader :expiration_in_seconds

        def initialize(expiration_in_seconds)
          @expiration_in_seconds = expiration_in_seconds
        end

        def perform
          null_timestamp = null_timestamp_for_db(DropletModel.db.database_type)
          DropletModel.
            where(state: [DropletModel::STAGING_STATE, DropletModel::PROCESSING_UPLOAD_STATE]).
            where(
              (updated_at_past_threshold & Sequel.~({ updated_at: null_timestamp })) |
                (created_at_past_threshold & { updated_at: null_timestamp })
            ).
            update(
              state:      DropletModel::FAILED_STATE,
              error_id:   'StagingTimeExpired',
              updated_at: Sequel::CURRENT_TIMESTAMP
            )
        end

        def null_timestamp_for_db(db_type)
          {
            postgres: nil,
            mysql: '0000-00-00 00:00:00'
          }[db_type]
        end

        def job_name_in_configuration
          :pending_droplets
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
