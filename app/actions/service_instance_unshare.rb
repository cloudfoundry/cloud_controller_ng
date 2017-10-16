module VCAP::CloudController
  class ServiceInstanceUnshare
    def unshare(service_instance, target_space)
      service_instance.remove_shared_space(target_space)
    end
  end
end
