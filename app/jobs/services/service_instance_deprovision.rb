module VCAP::CloudController
  module Jobs
    module Services
      class ServiceInstanceDeprovision < VCAP::CloudController::Jobs::CCJob
        attr_accessor :name, :client_attrs, :service_instance_guid, :service_plan_guid

        def initialize(name, client_attrs, service_instance_guid, service_plan_guid)
          @name = name
          @client_attrs = client_attrs
          @service_instance_guid = service_instance_guid
          @service_plan_guid = service_plan_guid
        end

        def perform
          logger = Steno.logger('cc-background')
          logger.info('There was an error during service instance provisioning. Attempting to delete potentially orphaned instance.')

          client = VCAP::Services::ServiceBrokers::V2::Client.new(client_attrs)
          service_plan = ServicePlan.first(guid: service_plan_guid)
          service_instance = ManagedServiceInstance.new(guid: service_instance_guid, service_plan: service_plan)
          client.deprovision(service_instance)
        end

        def job_name_in_configuration
          :service_instance_deprovision
        end

        def max_attempts
          10
        end

        def reschedule_at(time, attempts)
          time + (2**attempts).minutes
        end
      end
    end
  end
end
