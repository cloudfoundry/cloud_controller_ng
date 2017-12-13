require 'repositories/service_instance_share_event_repository'

module VCAP::CloudController
  class ServiceInstanceShare
    def create(service_instance, target_spaces, user_audit_info)
      validate_supported_service_type!(service_instance)
      validate_service_instance_is_shareable!(service_instance)
      validate_target_spaces!(service_instance, target_spaces)

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

    def validate_target_spaces!(service_instance, target_spaces)
      validate_not_sharing_to_self!(service_instance, target_spaces)
      validate_plan_is_active!(service_instance)

      target_spaces.each do |space|
        validate_plan_visibility!(service_instance, space)
        validate_name_uniqueness!(service_instance, space)
      end
    end

    def validate_plan_is_active!(service_instance)
      if !service_instance.service_plan.active?
        error_msg = "The service instance could not be shared as the #{service_instance.service_plan.name} plan is inactive."
        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', error_msg)
      end
    end

    def validate_plan_visibility!(service_instance, space)
      unless service_instance.service_plan.visible_in_space?(space)
        error_msg = "Access to service #{service_instance.service.label} and plan #{service_instance.service_plan.name} is not enabled in #{space.organization.name}/#{space.name}"
        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', error_msg)
      end
    end

    def validate_name_uniqueness!(service_instance, space)
      if space.service_instances.map(&:name).include?(service_instance.name)
        raise CloudController::Errors::ApiError.new_from_details('SharedServiceInstanceNameTaken', service_instance.name, space.name)
      end
    end

    def validate_not_sharing_to_self!(service_instance, spaces)
      if spaces.include?(service_instance.space)
        raise CloudController::Errors::ApiError.new_from_details('InvalidServiceInstanceSharingTargetSpace')
      end
    end

    def validate_supported_service_type!(service_instance)
      if service_instance.route_service?
        raise CloudController::Errors::ApiError.new_from_details('RouteServiceInstanceSharingNotSupported')
      end

      unless service_instance.managed_instance?
        raise CloudController::Errors::ApiError.new_from_details('UserProvidedServiceInstanceSharingNotSupported')
      end
    end

    def validate_service_instance_is_shareable!(service_instance)
      unless service_instance.shareable?
        raise CloudController::Errors::ApiError.new_from_details('ServiceShareIsDisabled', service_instance.service.label)
      end
    end
  end
end
