module VCAP::CloudController
  class ServiceBindingModelDelete
    class FailedToDelete < StandardError; end

    def synchronous_delete(service_binding)
      if service_binding.service_instance.operation_in_progress?
        raise FailedToDelete.new("The service instance: #{service_binding.service_instance.name}, has another operation in progress")
      end

      begin
        service_binding.client.unbind(service_binding)
      rescue => e
        logger.error("Failed unbinding #{service_binding.guid}: #{e.message}")
        raise FailedToDelete.new(e.message)
      end

      service_binding.destroy
    end

    private

    def logger
      @logger ||= Steno.logger('cc.action.service_binding_model_delete')
    end
  end
end
