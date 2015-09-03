module VCAP::CloudController
  class ServiceInstancePurger
    def purge(service_instance)
      service_instance.service_bindings.each do |binding|
        binding.destroy
      end

      service_instance.service_keys.each do |key|
        key.destroy
      end

      service_instance.destroy
    end
  end
end
