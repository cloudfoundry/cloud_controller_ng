module VCAP::CloudController
  module Jobs
    module Services
      class ServiceBindingStateFetch < VCAP::CloudController::Jobs::CCJob
        def initialize(service_binding_guid, user_info, request_attrs)
          @service_binding_guid = service_binding_guid
          @end_timestamp = Time.now + VCAP::CloudController::Config.config.get(:broker_client_max_async_poll_duration_minutes).minutes
          @poll_interval = VCAP::CloudController::Config.config.get(:broker_client_default_async_poll_interval_seconds)
          @user_audit_info = user_info
          @request_attrs = request_attrs
        end

        def perform
          logger = Steno.logger('cc-background')
          service_binding = ServiceBinding.first(guid: @service_binding_guid)
          return if service_binding.nil? # assume the binding has been purged

          client = VCAP::Services::ServiceClientProvider.provide(instance: service_binding.service_instance)

          last_operation_result = client.fetch_service_binding_last_operation(service_binding)
          if last_operation_result[:last_operation][:state] == 'succeeded'
            begin
              binding_response = client.fetch_service_binding(service_binding)
            rescue HttpResponseError, VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerApiTimeout => e
              set_binding_failed_state(service_binding, logger)
              logger.error("There was an error while fetching the service binding details: #{e}")
              return
            end
            service_binding.update({ 'credentials' => binding_response[:credentials] })
            record_event(service_binding, @request_attrs)
          end

          service_binding.last_operation.update(last_operation_result[:last_operation])
          retry_job unless service_binding.terminal_state?
        rescue HttpResponseError, Sequel::Error, VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerApiTimeout => e
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

        def record_event(binding, request_attrs)
          user = User.find(guid: @user_audit_info.user_guid)

          if user
            Repositories::ServiceBindingEventRepository.record_create(binding, @user_audit_info, request_attrs)
          end
        end

        def enqueue_again
          opts = { queue: 'cc-generic', run_at: Delayed::Job.db_time_now + @poll_interval }
          VCAP::CloudController::Jobs::Enqueuer.new(self, opts).enqueue
        end

        def set_binding_failed_state(service_binding, logger)
          service_binding.last_operation.update(
            state: 'failed',
            description: 'A valid binding could not be fetched from the service broker.',
          )
          SynchronousOrphanMitigate.new(logger).attempt_unbind(service_binding)
        end
      end
    end
  end
end
