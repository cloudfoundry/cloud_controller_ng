module VCAP::CloudController
  module Jobs
    module Services
      class DeleteOrphanedBinding < VCAP::CloudController::Jobs::CCJob
        attr_accessor :name, :client_attrs, :binding_guid, :service_instance_guid, :app_guid

        def initialize(name, client_attrs, binding_guid, service_instance_guid, app_guid)
          @name = name
          @client_attrs = client_attrs
          @binding_guid = binding_guid
          @service_instance_guid = service_instance_guid
          @app_guid = app_guid
        end

        def perform
          logger = Steno.logger('cc-background')
          logger.info('There was an error during service binding creation. Attempting to delete potentially orphaned binding.')

          client = VCAP::Services::ServiceBrokers::V2::Client.new(client_attrs)
          app = VCAP::CloudController::App.first(guid: app_guid)
          service_instance = VCAP::CloudController::ServiceInstance.first(guid: service_instance_guid)

          service_binding = VCAP::CloudController::ServiceBinding.new(guid: binding_guid, app: app, service_instance: service_instance)
          client.unbind(service_binding)
        end

        def job_name_in_configuration
          :delete_orphaned_binding
        end

        def max_attempts
          11
        end

        def reschedule_at(time, attempts)
          time + (2**attempts).minutes
        end
      end

      # Keep the legacy name for backwards compatibility
      ServiceInstanceUnbind = DeleteOrphanedBinding
    end
  end
end
