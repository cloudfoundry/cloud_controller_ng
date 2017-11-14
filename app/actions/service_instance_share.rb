require 'repositories/service_instance_share_event_repository'

module VCAP::CloudController
  class ServiceInstanceShare
    def create(service_instance, target_spaces, user_audit_info)
      supported_service_type?(service_instance)
      service_instance_shareable?(service_instance)

      if target_spaces.include?(service_instance.space)
        raise CloudController::Errors::ApiError.new_from_details('InvalidServiceInstanceSharingTargetSpace')
      end

      target_spaces.each do |space|
        if space.service_instances.map(&:name).include?(service_instance.name)
          raise CloudController::Errors::ApiError.new_from_details('SharedServiceInstanceNameTaken', service_instance.name, space.name)
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

    private

    def supported_service_type?(service_instance)
      if service_instance.route_service?
        raise CloudController::Errors::ApiError.new_from_details('RouteServiceInstanceSharingNotSupported')
      end

      unless service_instance.managed_instance?
        raise CloudController::Errors::ApiError.new_from_details('UserProvidedServiceInstanceSharingNotSupported')
      end
    end

    def service_instance_shareable?(service_instance)
      unless service_instance.shareable?
        raise CloudController::Errors::ApiError.new_from_details('ServiceShareIsDisabled', service_instance.service.label)
      end
    end
  end
end
