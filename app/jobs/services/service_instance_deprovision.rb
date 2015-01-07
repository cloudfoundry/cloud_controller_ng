module VCAP::CloudController
  module Jobs
    module Services
      class ServiceInstanceDeprovision < Struct.new(:name, :client_attrs, :service_instance_guid, :service_plan_guid)
        def perform
          client = VCAP::Services::ServiceBrokers::V2::Client.new(client_attrs)
          service_plan = ServicePlan.first(guid: service_plan_guid)
          service_instance = ManagedServiceInstance.new(guid: service_instance_guid, service_plan: service_plan)
          client.deprovision(service_instance)
        end

        def job_name_in_configuration
          :service_instance_deprovision
        end

        def max_attempts
          1
        end
      end
    end
  end
end
