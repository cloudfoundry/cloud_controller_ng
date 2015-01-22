module VCAP::CloudController
  module Jobs
    module Runtime
      class PendingPackagesCleanup < VCAP::CloudController::Jobs::CCJob
        attr_accessor :expiration_in_seconds

        def initialize(expiration_in_seconds)
          @expiration_in_seconds = expiration_in_seconds
        end

        def perform
          App.where("package_pending_since < ? - INTERVAL '?' SECOND", Sequel::CURRENT_TIMESTAMP, expiration_in_seconds.to_i).update(
            package_state: 'FAILED',
            staging_failed_reason: 'StagingTimeExpired',
            package_pending_since: nil,
          )
        end

        def job_name_in_configuration
          :pending_packages
        end

        def max_attempts
          1
        end
      end
    end
  end
end
