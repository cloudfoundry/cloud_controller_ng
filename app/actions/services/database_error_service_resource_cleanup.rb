module VCAP::CloudController
  class DatabaseErrorServiceResourceCleanup
    def initialize(logger)
      @logger = logger
    end

    def attempt_deprovision_instance(service_instance)
      @logger.info "Attempting synchronous orphan mitigation for service instance #{service_instance.guid}"
      client(service_instance).deprovision(service_instance, accepts_incomplete: true)
      @logger.info "Success deprovisioning orphaned service instance #{service_instance.guid}"
    rescue StandardError => e
      @logger.error "Unable to deprovision orphaned service instance #{service_instance.guid}: #{e}"
    end

    def attempt_delete_key(service_key)
      @logger.info "Attempting synchronous orphan mitigation for service key #{service_key.guid}"
      service_instance = service_key.service_instance
      client(service_instance).unbind(service_key)
      @logger.info "Success deleting orphaned service key #{service_key.guid}"
    rescue StandardError => e
      @logger.error "Unable to delete orphaned service key #{service_key.guid}: #{e}"
    end

    def attempt_unbind(service_binding)
      @logger.info "Attempting synchronous orphan mitigation for service binding #{service_binding.guid}"
      service_instance = service_binding.service_instance
      client(service_instance).unbind(service_binding, accepts_incomplete: true)
      @logger.info "Success unbinding orphaned service binding #{service_binding.guid}"
    rescue StandardError => e
      @logger.error "Unable to delete orphaned service binding #{service_binding.guid}: #{e}"
    end

    private

    def client(instance)
      VCAP::Services::ServiceClientProvider.provide(instance:)
    end
  end
end
