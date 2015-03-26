module VCAP::CloudController
  class ServiceKeyDelete
    def delete(service_key_dataset)
      service_key_dataset.each_with_object([]) do |service_key, errs|
        begin
          service_key.client.unbind(service_key)
          service_key.destroy
        rescue HttpRequestError, HttpResponseError => e
          errs << e
        end
        errs
      end
    end
  end
end
