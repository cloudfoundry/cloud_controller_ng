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
          DropletModel.
            where(state: [DropletModel::STAGING_STATE, DropletModel::PROCESSING_UPLOAD_STATE]).
            where(updated_at_past_threshold).
            update(
              state:      DropletModel::FAILED_STATE,
              error_id:   'StagingTimeExpired',
              updated_at: Sequel::CURRENT_TIMESTAMP
            )
        end

        def job_name_in_configuration
          :pending_droplets
        end

        def max_attempts
          1
        end

        private

        def updated_at_past_threshold
          if Sequel::Model.db.database_type == :mssql
            return Sequel.lit(
              'UPDATED_AT < DATEADD(SECOND, -?, ?)',
                      expiration_threshold,
                      Sequel::CURRENT_TIMESTAMP
                   )
          else
            return Sequel.lit(
              "updated_at < ? - INTERVAL '?' SECOND",
                      Sequel::CURRENT_TIMESTAMP,
                      expiration_threshold
                   )
          end
        end

        def created_at_past_threshold
          if Sequel::Model.db.database_type == :mssql
            return Sequel.lit(
              'CREATED_AT < DATEADD(SECOND, -?, ?)',
                      expiration_threshold,
                      Sequel::CURRENT_TIMESTAMP
                   )
          else
            return Sequel.lit(
              "created_at < ? - INTERVAL '?' SECOND",
                      Sequel::CURRENT_TIMESTAMP,
                      expiration_threshold
                   )
          end
        end

        def expiration_threshold
          expiration_in_seconds + ADDITIONAL_EXPIRATION_TIME_IN_SECONDS
        end
      end
    end
  end
end
