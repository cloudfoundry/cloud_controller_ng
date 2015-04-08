require 'actions/locks/binder_lock'

module VCAP::CloudController
  class ServiceBindingDelete
    def delete(service_binding_dataset)
      service_binding_dataset.each_with_object([]) do |service_binding, errs|
        errs.concat delete_service_binding(service_binding.service_instance, service_binding)
      end
    end

    private

    def delete_service_binding(service_instance, service_binding)
      errors = []

      begin
        lock = BinderLock.new(service_instance)
        lock.lock!

        service_instance.client.unbind(service_binding)
        service_binding.destroy

      rescue => e
        errors << e
      ensure
        lock.unlock_and_revert_operation! if lock.needs_unlock?
      end

      errors
    end
  end
end
