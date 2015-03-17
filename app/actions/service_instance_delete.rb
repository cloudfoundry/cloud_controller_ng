require 'actions/service_binding_delete'
require 'actions/deletion_errors'

module VCAP::CloudController
  class ServiceInstanceDelete
    def delete(service_instance_dataset)
      service_instance_dataset.each_with_object([]) do |service_instance, errs|
        errors = ServiceBindingDelete.new.delete(service_instance.service_bindings_dataset)
        errs.concat(errors)
        if errors.empty?
          begin
            service_instance.client.deprovision(service_instance)
            service_instance.destroy
          rescue HttpRequestError, HttpResponseError => e
            errs << ServiceInstanceDeletionError.new(e)
          end
        end
      end
    end
  end
end
