module VCAP::CloudController
  module Jobs
    module Services
      class ServiceBindingStateFetch < VCAP::CloudController::Jobs::CCJob

        def initialize(service_binding_guid)
          @service_binding_guid = service_binding_guid
          @end_timestamp = Time.now + VCAP::CloudController::Config.config.get(:broker_client_max_async_poll_duration_minutes).minutes
          @poll_interval = VCAP::CloudController::Config.config.get(:broker_client_default_async_poll_interval_seconds)
        end

        def perform
          if Time.now + @poll_interval > @end_timestamp
            ServiceBinding.first(guid: @service_binding_guid).last_operation.update(
              state: 'failed',
              description: 'Service Broker failed to bind within the required time.'
            )
          else
            enqueue_again
          end
        end

        private

        def enqueue_again
          opts = { queue: 'cc-generic', run_at: Delayed::Job.db_time_now + @poll_interval }
          VCAP::CloudController::Jobs::Enqueuer.new(self, opts).enqueue
        end
      end
    end
  end
end
