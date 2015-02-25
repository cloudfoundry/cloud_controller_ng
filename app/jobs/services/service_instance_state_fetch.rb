require 'controllers/services/lifecycle/service_instance_state_updater'

module VCAP::CloudController
  module Jobs
    module Services
      class ServiceInstanceStateFetch < VCAP::CloudController::Jobs::CCJob
        attr_accessor :name, :client_attrs, :service_instance_guid, :services_event_repository_opts, :request_attrs, :poll_interval

        def initialize(name, client_attrs, service_instance_guid, services_event_repository_opts, request_attrs, poll_interval)
          @name = name
          @client_attrs = client_attrs
          @service_instance_guid = service_instance_guid
          @services_event_repository_opts = services_event_repository_opts
          @request_attrs = request_attrs
          @poll_interval = poll_interval
        end

        def perform
          client = VCAP::Services::ServiceBrokers::V2::Client.new(client_attrs)
          service_instance = ManagedServiceInstance.first(guid: service_instance_guid)
          services_event_repository = Repositories::Services::EventRepository.new(@services_event_repository_opts) if @services_event_repository_opts

          updater = ServiceInstanceStateUpdater.new(client, services_event_repository, self)
          updater.update_instance_state(service_instance, @request_attrs)
        end

        def retry_state_updater(client_attrs, service_instance)
          poller = VCAP::Services::ServiceBrokers::V2::ServiceInstanceStatePoller.new
          poller.poll_service_instance_state(client_attrs, service_instance, @services_event_repository_opts, @request_attrs, @poll_interval)
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
