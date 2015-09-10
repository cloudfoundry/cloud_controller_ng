module VCAP::CloudController
  module Jobs
    module Services
      class ServiceInstanceStateFetch < VCAP::CloudController::Jobs::CCJob
        attr_accessor :name, :client_attrs, :service_instance_guid, :services_event_repository, :request_attrs, :poll_interval, :end_timestamp

        def initialize(name, client_attrs, service_instance_guid, services_event_repository, request_attrs, end_timestamp=nil, services_event_repository_opts=nil)
          @name = name
          @client_attrs = client_attrs
          @service_instance_guid = service_instance_guid
          get_repository(services_event_repository, services_event_repository_opts)
          @request_attrs = request_attrs
          @end_timestamp = end_timestamp || new_end_timestamp
          update_polling_interval
        end

        def perform
          client = VCAP::Services::ServiceBrokers::V2::Client.new(client_attrs)
          service_instance = ManagedServiceInstance.first(guid: service_instance_guid)

          attrs_to_update = client.fetch_service_instance_state(service_instance)
          update_with_attributes(attrs_to_update, service_instance)

          retry_state_updater unless service_instance.terminal_state?
        rescue HttpRequestError, HttpResponseError, Sequel::Error => e
          logger = Steno.logger('cc-background')
          logger.error("There was an error while fetching the service instance operation state: #{e}")
          retry_state_updater
        end

        def job_name_in_configuration
          :service_instance_state_fetch
        end

        def max_attempts
          1
        end

        private

        def new_end_timestamp
          Time.now + VCAP::CloudController::Config.config[:broker_client_max_async_poll_duration_minutes].minutes
        end

        def get_repository(services_event_repository, services_event_repository_opts)
          @services_event_repository = services_event_repository
          if services_event_repository_opts && !@services_event_repository
            @services_event_repository = Repositories::Services::EventRepository.new(services_event_repository_opts)
          end
        end

        def update_with_attributes(attrs_to_update, service_instance)
          ServiceInstance.db.transaction do
            service_instance.lock!
            service_instance.save_and_update_operation(
                last_operation: attrs_to_update[:last_operation].slice(:state, :description)
            )

            if service_instance.last_operation.state == 'succeeded'
              apply_proposed_changes(service_instance)
              record_event(@services_event_repository, service_instance, @request_attrs)
            end
          end
        end

        def retry_state_updater
          update_polling_interval
          if Time.now + @poll_interval > end_timestamp
            ManagedServiceInstance.first(guid: service_instance_guid).save_and_update_operation(
                last_operation: {
                    state: 'failed',
                    description: 'Service Broker failed to provision within the required time.',
                }
            )
          else
            enqueue_again
          end
        end

        def record_event(services_event_repository, service_instance, request_attrs)
          return unless services_event_repository
          type = service_instance.last_operation.type.to_sym
          services_event_repository.record_service_instance_event(type, service_instance, request_attrs)
        end

        def apply_proposed_changes(service_instance)
          if service_instance.last_operation.type == 'delete'
            service_instance.last_operation.destroy
            service_instance.destroy
          else
            service_instance.save_and_update_operation(service_instance.last_operation.proposed_changes)
          end
        end

        def enqueue_again
          opts = { queue: 'cc-generic', run_at: Delayed::Job.db_time_now + @poll_interval }
          VCAP::CloudController::Jobs::Enqueuer.new(self, opts).enqueue
        end

        def update_polling_interval
          default_poll_interval = VCAP::CloudController::Config.config[:broker_client_default_async_poll_interval_seconds]
          poll_interval = [default_poll_interval, 24.hours].min
          @poll_interval = poll_interval
        end
      end
    end
  end
end
