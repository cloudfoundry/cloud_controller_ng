module VCAP::CloudController
  class SynchronousOrphanMitigate
    def initialize(logger)
      @logger = logger
    end

    def attempt_deprovision_instance(service_instance)
      @logger.info "Attempting synchronous orphan mitigation for service instance #{service_instance.guid}"
      client = VCAP::Services::ServiceClientProvider.provide(instance: service_instance)
      client.deprovision(service_instance)
      @logger.info "Success deprovisioning orphaned service instance #{service_instance.guid}"
    rescue => e
      @logger.error "Unable to deprovision orphaned service instance #{service_instance.guid}: #{e}"
    end

    def attempt_delete_key(service_key)
      @logger.info "Attempting synchronous orphan mitigation for service key #{service_key.guid}"
      client = VCAP::Services::ServiceClientProvider.provide(binding: service_key)
      client.unbind(service_key)
      @logger.info "Success deleting orphaned service key #{service_key.guid}"
    rescue => e
      @logger.error "Unable to delete orphaned service key #{service_key.guid}: #{e}"
    end

    def attempt_unbind(service_binding)
      @logger.info "Attempting synchronous orphan mitigation for service binding #{service_binding.guid}"
      client = VCAP::Services::ServiceClientProvider.provide(binding: service_binding)
      client.unbind(service_binding)
      @logger.info "Success unbinding orphaned service binding #{service_binding.guid}"
    rescue => e
      @logger.error "Unable to delete orphaned service binding #{service_binding.guid}: #{e}"
    end
  end
end
