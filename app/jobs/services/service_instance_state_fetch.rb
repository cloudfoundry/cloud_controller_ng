module VCAP::CloudController
  module Jobs
    module Services
      class ServiceInstanceStateFetch < VCAP::CloudController::Jobs::CCJob
        attr_accessor :name, :client_attrs, :service_instance_guid

        def initialize(name, client_attrs, service_instance_guid)
          @name = name
          @client_attrs = client_attrs
          @service_instance_guid = service_instance_guid
        end

        def perform
          logger = Steno.logger('cc-background')
          client = VCAP::Services::ServiceBrokers::V2::Client.new(client_attrs)
          service_instance = ManagedServiceInstance.first(guid: service_instance_guid)

          poller = VCAP::Services::ServiceBrokers::V2::ServiceInstanceStatePoller.new
          begin
            attrs = client.fetch_service_instance_state(service_instance)

            service_instance.update_state(attrs)

            if !service_instance.terminal_state?
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
