require 'actions/services/database_error_service_resource_cleanup'
require 'actions/services/locks/lock_check'

module VCAP::CloudController
  class ServiceKeyCreate
    include VCAP::CloudController::LockCheck

    def initialize(logger)
      @logger = logger
    end

    def create(service_instance, key_attrs, arbitrary_parameters)
      errors = []

      begin
        raise_if_instance_locked(service_instance)

        service_key = ServiceKey.new(key_attrs)

        client = VCAP::Services::ServiceClientProvider.provide(instance: service_instance)
        attributes_to_update = client.create_service_key(service_key, arbitrary_parameters: arbitrary_parameters)

        begin
          service_key.set(attributes_to_update)
          service_key.save
        rescue => e
          @logger.error "Failed to save state of create for service key #{service_key.guid} with exception: #{e}"
          service_resource_cleanup = DatabaseErrorServiceResourceCleanup.new(@logger)
          service_resource_cleanup.attempt_delete_key(service_key)
          raise
        end
      rescue => e
        errors << e
      end

      [service_key, errors]
    end
  end
end
