module VCAP::CloudController
  class SynchronousOrphanMitigate
    def initialize(logger)
      @logger = logger
    end

    def attempt_deprovision_instance(service_instance)
      service_instance.client.deprovision(service_instance)
    rescue => e
      @logger.error "Unable to deprovision orphaned instance #{service_instance} from broker: #{e}"
    end

    def attempt_delete_key(service_key)
      service_key.client.unbind(service_key)
    rescue => e
      @logger.error "Unable to delete orphaned key #{service_key} from broker: #{e}"
    end

    def attempt_unbind(service_binding)
      service_binding.client.unbind(service_binding)
    rescue => e
      @logger.error "Unable to delete orphaned binding #{service_binding} from broker: #{e}"
    end
  end
end
