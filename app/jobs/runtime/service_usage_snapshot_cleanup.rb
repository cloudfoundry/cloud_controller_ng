module VCAP::CloudController
  module Jobs
    module Runtime
      class ServiceUsageSnapshotCleanup < VCAP::CloudController::Jobs::CCJob
        attr_accessor :cutoff_age_in_days

        def initialize(cutoff_age_in_days)
          @cutoff_age_in_days = cutoff_age_in_days
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info("Cleaning up service usage snapshots older than #{cutoff_age_in_days} days")

          cutoff_time = Time.now.utc - cutoff_age_in_days.days

          old_completed = ServiceUsageSnapshot.where(
            Sequel.lit('created_at < ? AND completed_at IS NOT NULL', cutoff_time)
          )

          stale_timeout = Time.now.utc - 1.hour
          stale_in_progress = ServiceUsageSnapshot.where(
            Sequel.lit('created_at < ? AND completed_at IS NULL', stale_timeout)
          )

          completed_count = old_completed.count
          stale_count = stale_in_progress.count

          old_completed.delete
          stale_in_progress.delete

          logger.info("Deleted #{completed_count} old completed snapshots and #{stale_count} stale in-progress snapshots")
        end

        def job_name_in_configuration
          :service_usage_snapshot_cleanup
        end

        def max_attempts
          1
        end
      end
    end
  end
end
