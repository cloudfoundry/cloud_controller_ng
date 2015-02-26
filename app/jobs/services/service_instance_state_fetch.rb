require 'controllers/services/lifecycle/service_instance_state_updater'

module VCAP::CloudController
  module Jobs
    module Services
      class ServiceInstanceStateFetch < VCAP::CloudController::Jobs::CCJob
        attr_accessor :name, :client_attrs, :service_instance_guid, :services_event_repository_opts, :request_attrs, :poll_interval, :attempts_remaining

        def initialize(name, client_attrs, service_instance_guid, services_event_repository_opts, request_attrs, poll_interval=nil, attempts_remaining=nil)
          @name = name
          @client_attrs = client_attrs
          @service_instance_guid = service_instance_guid
          @services_event_repository_opts = services_event_repository_opts
          @request_attrs = request_attrs
          @attempts_remaining = attempts_remaining || VCAP::CloudController::Config.config[:broker_client_max_async_poll_attempts]

          default_poll_interval = VCAP::CloudController::Config.config[:broker_client_default_async_poll_interval_seconds]
          poll_interval ||= default_poll_interval
          poll_interval = [[default_poll_interval, poll_interval].max, 24.hours].min
          @poll_interval = poll_interval
        end

        def enqueue
          opts = { queue: 'cc-generic', run_at: Delayed::Job.db_time_now + @poll_interval }
          VCAP::CloudController::Jobs::Enqueuer.new(self, opts).enqueue
        end

        def perform
          client = VCAP::Services::ServiceBrokers::V2::Client.new(client_attrs)
          service_instance = ManagedServiceInstance.first(guid: service_instance_guid)
          services_event_repository = Repositories::Services::EventRepository.new(@services_event_repository_opts) if @services_event_repository_opts

          updater = ServiceInstanceStateUpdater.new(client, services_event_repository, self)
          updater.update_instance_state(service_instance, @request_attrs)
        end

        def retry_state_updater
          @attempts_remaining -= 1
          if @attempts_remaining == 0
            ManagedServiceInstance.first(guid: service_instance_guid).save_with_operation(
              last_operation: {
                state: 'failed',
                description: 'Service Broker failed to provision within the required time.',
              }
            )
          else
            enqueue
          end
        end

        def job_name_in_configuration
          :service_instance_state_fetch
        end

        def max_attempts
          1
        end
      end
    end
  end
end
