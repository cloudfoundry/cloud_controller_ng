require 'actions/locks/binder_lock'

module VCAP::CloudController
  class ServiceKeyDelete
    def delete(service_keys_dataset)
      service_keys_dataset.each_with_object([]) do |service_key, errs|
        errs.concat delete_service_key(service_key.service_instance, service_key)
      end
    end

    private

    def delete_service_key(service_instance, service_key)
      errors = []

      begin
        lock = BinderLock.new(service_instance)
        lock.lock!

        service_instance.client.unbind(service_key)
        service_key.destroy

      rescue => e
        errors << e
      ensure
        lock.unlock_and_revert_operation! if lock.needs_unlock?
      end

      errors
    end
  end
end
