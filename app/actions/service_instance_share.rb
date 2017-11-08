require 'repositories/service_instance_share_event_repository'

module VCAP::CloudController
  class ServiceInstanceShare
    def create(service_instance, target_spaces, user_audit_info)
      if service_instance.managed_instance?
        unless service_instance.shareable?
          raise CloudController::Errors::ApiError.new_from_details('ServiceShareIsDisabled', service_instance.service.label)
        end
      end

      ServiceInstance.db.transaction do
        target_spaces.each do |space|
          service_instance.add_shared_space(space)
        end
      end

      Repositories::ServiceInstanceShareEventRepository.record_share_event(
        service_instance, target_spaces.map(&:guid), user_audit_info
      )
      service_instance
    end
  end
end
