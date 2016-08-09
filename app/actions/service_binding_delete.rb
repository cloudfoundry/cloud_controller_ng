module VCAP::CloudController
  class ServiceBindingModelDelete
    class FailedToDelete < StandardError; end
    class OperationInProgress < FailedToDelete; end

    def initialize(user_guid, user_email)
      @user_guid = user_guid
      @user_email = user_email
    end

    def delete_sync(service_binding)
      delete(Array(service_binding))
    end

    def delete_async(service_binding)
      Jobs::Enqueuer.new(
        Jobs::DeleteActionJob.new(ServiceBinding, service_binding.guid, self),
        queue: 'cc-generic'
      ).enqueue
    end

    def delete(service_binding_dataset)
      service_binding = service_binding_dataset.first

      if service_binding.service_instance.operation_in_progress?
        raise OperationInProgress.new("The service instance: #{service_binding.service_instance.name}, has another operation in progress")
      end

      begin
        service_binding.client.unbind(service_binding)
      rescue => e
        logger.error("Failed unbinding #{service_binding.guid}: #{e.message}")
        raise e
      end

      Repositories::ServiceBindingEventRepository.record_delete(service_binding, @user_guid, @user_email)
      service_binding.destroy

      []
    end

    private

    def logger
      @logger ||= Steno.logger('cc.action.service_binding_model_delete')
    end
  end
end
