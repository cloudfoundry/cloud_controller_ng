module VCAP::CloudController
  class ServiceInstanceShare
    def create(service_instance, target_spaces, user_audit_info, target_space_guids)
      ServiceInstance.db.transaction do
        target_spaces.each do |space|
          service_instance.add_shared_space(space)
        end
      end

      Repositories::ServiceInstanceShareEventRepository.record_share_event(
        service_instance, user_audit_info, target_space_guids)
      service_instance
    end
  end
end
