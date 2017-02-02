require 'actions/services/locks/lock_check'

module VCAP::CloudController
  class ServiceBindingDelete
    class FailedToDelete < StandardError; end
    class OperationInProgress < FailedToDelete; end

    include VCAP::CloudController::LockCheck

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def single_delete_sync(service_binding)
      errors = delete(service_binding)
      raise errors.first unless errors.empty?
    end

    def single_delete_async(service_binding)
      Jobs::Enqueuer.new(
        Jobs::DeleteActionJob.new(ServiceBinding, service_binding.guid, self),
        queue: 'cc-generic'
      ).enqueue
    end

    def delete(service_bindings)
      bindings_to_delete = Array(service_bindings)

      errors = each_with_error_aggregation(bindings_to_delete) do |binding|
        raise_if_locked(binding.service_instance)
        remove_from_broker(binding)
        Repositories::ServiceBindingEventRepository.record_delete(binding, @user_audit_info)
        binding.destroy
      end

      errors
    end

    private

    def logger
      @logger ||= Steno.logger('cc.action.service_binding_delete')
    end

    def remove_from_broker(binding)
      binding.unbind_from_broker
    rescue => e
      logger.error("Failed unbinding #{binding.guid}: #{e.message}")
      raise e
    end

    def each_with_error_aggregation(list)
      errors = []
      list.each do |item|
        begin
          yield(item)
        rescue => e
          errors << e
        end
      end
      errors
    end
  end
end
