module VCAP::CloudController
  class ServiceBindingDelete
    def delete(service_binding_dataset)
      service_binding_dataset.each_with_object([]) do |service_binding, errs|
        begin
          service_binding.client.unbind(service_binding)
          service_binding.destroy
        rescue HttpRequestError, HttpResponseError => e
          errs << ServiceBindingDeletionError.new(e)
        end
        errs
      end
    end
  end
end
