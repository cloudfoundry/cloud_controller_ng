module VCAP::CloudController
  module Jobs
    module Services
      class ServiceInstanceStateFetch < VCAP::CloudController::Jobs::CCJob
        attr_accessor :name, :client_attrs, :service_instance_guid, :services_event_repository_opts, :request_attrs

        def initialize(name, client_attrs, service_instance_guid, services_event_repository_opts, request_attrs)
          @name = name
          @client_attrs = client_attrs
          @service_instance_guid = service_instance_guid
          @services_event_repository_opts = services_event_repository_opts
          @request_attrs = request_attrs
        end

        def perform
          logger = Steno.logger('cc-background')
          client = VCAP::Services::ServiceBrokers::V2::Client.new(client_attrs)
          service_instance = ManagedServiceInstance.first(guid: service_instance_guid)
          services_event_repository = nil
          if @services_event_repository_opts
            services_event_repository = Repositories::Services::EventRepository.new(@services_event_repository_opts)
          end

          poller = VCAP::Services::ServiceBrokers::V2::ServiceInstanceStatePoller.new
          begin
            attrs = client.fetch_service_instance_state(service_instance)

            ServiceInstance.db.transaction do
              service_instance.lock!
              service_instance.save_with_operation(
                last_operation: attrs[:last_operation].slice(:state, :description),
                dashboard_url: attrs[:dashboard_url],
              )

              if service_instance.last_operation.state == 'succeeded'
                if service_instance.last_operation.type == 'delete'
                  service_instance.last_operation.try(:destroy)
                  service_instance.delete
                else
                  service_instance.save_with_operation(service_instance.last_operation.proposed_changes)
                end

                if services_event_repository
                  services_event_repository.record_service_instance_event(:create, service_instance, @request_attrs)
                end
              end
            end

            unless service_instance.terminal_state?
              poller.poll_service_instance_state(client_attrs, service_instance)
            end

          rescue HttpRequestError, HttpResponseError, Sequel::Error => e
            logger.error("There was an error while fetching the service instance operation state: #{e}")
            poller.poll_service_instance_state(client_attrs, service_instance)
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
