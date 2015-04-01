require 'actions/service_binding_delete'
require 'actions/deletion_errors'

module VCAP::CloudController
  class ServiceInstanceDelete
    def delete(service_instance_dataset)
      service_instance_dataset.each_with_object([]) do |service_instance, errs|
        errs = delete_service_instance(service_instance, errs)
        errs
      end
    end

    private

    def delete_service_instance(service_instance, errs)
      errors = ServiceBindingDelete.new.delete(service_instance.service_bindings_dataset)
      errs.concat(errors)
      if errors.empty?
        begin
          service_instance.client.deprovision(service_instance)
          service_instance.destroy
        rescue => e
          errs << e
        ensure
          service_instance.save_with_operation(
            last_operation: {
              type: 'delete',
              state: 'failed',
            }
          ) if service_instance.exists?
        end
      end
      errs
    end
  end
end
