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
          binding = ServiceBinding.first(guid: @service_binding_guid)
          return if binding.nil? # assume the binding has been purged

          client = VCAP::Services::ServiceClientProvider.provide(instance: binding.service_instance)

          last_operation_result = client.fetch_service_binding_last_operation(binding)
          binding.last_operation.update(last_operation_result[:last_operation])
          retry_job unless binding.last_operation.state == 'failed'
        rescue HttpResponseError, Sequel::Error, VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerApiTimeout => e
          logger = Steno.logger('cc-background')
          logger.error("There was an error while fetching the service binding operation state: #{e}")
          retry_job
        end

        def max_attempts
          1
        end

        private

        def retry_job
          if Time.now + @poll_interval > @end_timestamp
            ServiceBinding.first(guid: @service_binding_guid).last_operation.update(
              state: 'failed',
              description: 'Service Broker failed to bind within the required time.'
            )
          else
            enqueue_again
          end
        end

        def enqueue_again
          opts = { queue: 'cc-generic', run_at: Delayed::Job.db_time_now + @poll_interval }
          VCAP::CloudController::Jobs::Enqueuer.new(self, opts).enqueue
        end
      end
    end
  end
end
