module VCAP::CloudController
  class ServiceInstanceUnshare
    def unshare(service_instance, target_space, user_audit_info)
      service_instance.remove_shared_space(target_space)

      Repositories::ServiceInstanceShareEventRepository.record_unshare_event(
        service_instance, target_space.guid, user_audit_info)
    end
  end
end
