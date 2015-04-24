module VCAP::CloudController
  class ServiceKeyCreate
    def initialize(logger)
      @logger = logger
    end

    def create(service_instance, key_attrs, request_params)
      errors = []

      begin
        lock = BinderLock.new(service_instance)
        lock.lock!

        service_key = ServiceKey.new(key_attrs)
        attributes_to_update = service_key.client.bind(service_key, request_params: request_params)

        begin
          service_key.set_all(attributes_to_update)
          service_key.save
        rescue
          safe_delete_key(service_key)
          raise
        end

      rescue => e
        errors << e
      ensure
        lock.unlock_and_revert_operation! if lock.needs_unlock?
      end

      [service_key, errors]
    end

    private

    def safe_delete_key(service_key)
      service_key.client.unbind(service_key)
    rescue => e
      @logger.error "Unable to delete key #{service_key}: #{e}"
    end
  end
end
