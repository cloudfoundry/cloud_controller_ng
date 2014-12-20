module VCAP::CloudController
  module Jobs
    module Services
      class ServiceInstanceUnbind < Struct.new(:name, :client_attrs, :binding_guid, :service_instance_guid, :app_guid)
        def perform
          client = VCAP::Services::ServiceBrokers::V2::Client.new(client_attrs)
          app = VCAP::CloudController::App.first(guid: app_guid)
          service_instance = VCAP::CloudController::ServiceInstance.first(guid: service_instance_guid)

          binding = VCAP::CloudController::ServiceBinding.new(guid: binding_guid, app: app, service_instance: service_instance)

          client.unbind(binding)
        end

        def job_name_in_configuration
          :service_instance_unbind
        end

        def max_attempts
          3
        end
      end
    end
  end
end
