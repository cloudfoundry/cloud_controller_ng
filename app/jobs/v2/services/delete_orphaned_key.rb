module VCAP::CloudController
  module Jobs
    module Services
      class DeleteOrphanedKey < VCAP::CloudController::Jobs::CCJob
        attr_accessor :name, :key_guid, :service_instance_guid

        def initialize(name, key_guid, service_instance_guid)
          @name = name
          @key_guid = key_guid
          @service_instance_guid = service_instance_guid
        end

        def perform
          logger = Steno.logger('cc-background')
          logger.info("There was an error during service key creation. Attempting to delete potentially created key. Instance guid: #{service_instance_guid}, Key guid #{key_guid}")

          service_instance = VCAP::CloudController::ManagedServiceInstance.first(guid: service_instance_guid)
          client = VCAP::Services::ServiceClientProvider.provide(instance: service_instance)

          service_key = VCAP::CloudController::ServiceKey.new(guid: key_guid, service_instance: service_instance)
          client.unbind(service_key)
        end

        def job_name_in_configuration
          :delete_orphaned_key
        end

        def max_attempts
          11
        end

        def reschedule_at(time, attempts)
          time + (2**attempts).minutes
        end
      end
    end
  end
end
