module VCAP::CloudController
  module Jobs
    module Services
      class OrphanedBindingInfo
        attr_accessor :guid, :service_instance_guid

        def initialize(binding)
          @guid                  = binding.guid
          @service_instance_guid = binding.service_instance.guid
          @service_instance_name = binding.service_instance.name
          @service_id            = binding.service.broker_provided_id
          @plan_id               = binding.service_plan.broker_provided_id
        end

        def to_binding
          binding                  = OpenStruct.new(guid: @guid)
          binding.service_instance = OpenStruct.new(guid: @service_instance_guid, name: @service_instance_name)
          binding.service          = OpenStruct.new(broker_provided_id: @service_id)
          binding.service_plan     = OpenStruct.new(broker_provided_id: @plan_id)
          binding
        end
      end

      class DeleteOrphanedBinding < VCAP::CloudController::Jobs::CCJob
        attr_accessor :name, :client_attrs, :binding_info

        def initialize(name, binding_info)
          @name                  = name
          @binding_info          = binding_info
        end

        def perform
          logger = Steno.logger('cc-background')
          logger.info('There was an error during service binding creation. Attempting to delete potentially orphaned binding. ' \
                      "Instance guid: #{binding_info.service_instance_guid}, Binding guid #{binding_info.guid}")

          service_instance = ManagedServiceInstance.find(guid: binding_info.service_instance_guid)
          client = VCAP::Services::ServiceClientProvider.provide(instance: service_instance)
          client.unbind(binding_info.to_binding, accepts_incomplete: true)
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
