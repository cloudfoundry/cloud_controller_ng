module VCAP::CloudController
  module Jobs
    module Runtime
      class RequestCountsCleanup < VCAP::CloudController::Jobs::CCJob
        def perform
          logger = Steno.logger('cc.background')
          logger.info('Cleaning up no-longer-valid RequestCount rows')

          deleted_count = VCAP::CloudController::RequestCount.where(Sequel[:valid_until] < Time.now).delete

          logger.info("Cleaned up #{deleted_count} RequestCount rows")
        end

        def job_name_in_configuration
          :request_counts_cleanup
        end

        def max_attempts
          1
        end
      end
    end
  end
end
