require 'repositories/service_instance_share_event_repository'

module VCAP::CloudController
  class ServiceInstanceShare
    def create(service_instance, target_spaces, user_audit_info)
      supported_service_type!(service_instance)
      service_instance_shareable!(service_instance)
      valid_target_spaces!(service_instance, target_spaces)

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

    def valid_target_spaces!(service_instance, target_spaces)
      no_sharing_to_self!(service_instance, target_spaces)
      plan_active!(service_instance)

      target_spaces.each do |space|
        plan_visibility!(service_instance, space)
        name_uniqueness!(service_instance, space)
      end
    end

    def plan_active!(service_instance)
      if !service_instance.service_plan.active?
        error_msg = "The service instance could not be shared as the plan #{service_instance.service_plan.name} is inactive."
        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', error_msg)
      end
    end

    def plan_visibility!(service_instance, space)
      visible_plans = ServicePlan.organization_visible(space.organization)

      if !visible_plans.include?(service_instance.service_plan)
        error_msg = "Access to service #{service_instance.service.label} and plan #{service_instance.service_plan.name} is not enabled in #{space.organization.name}/#{space.name}"
        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', error_msg)
      end
    end

    def name_uniqueness!(service_instance, space)
      if space.service_instances.map(&:name).include?(service_instance.name)
        raise CloudController::Errors::ApiError.new_from_details('SharedServiceInstanceNameTaken', service_instance.name, space.name)
      end
    end

    def no_sharing_to_self!(service_instance, spaces)
      if spaces.include?(service_instance.space)
        raise CloudController::Errors::ApiError.new_from_details('InvalidServiceInstanceSharingTargetSpace')
      end
    end

    def supported_service_type!(service_instance)
      if service_instance.route_service?
        raise CloudController::Errors::ApiError.new_from_details('RouteServiceInstanceSharingNotSupported')
      end

      unless service_instance.managed_instance?
        raise CloudController::Errors::ApiError.new_from_details('UserProvidedServiceInstanceSharingNotSupported')
      end
    end

    def service_instance_shareable!(service_instance)
      unless service_instance.shareable?
        raise CloudController::Errors::ApiError.new_from_details('ServiceShareIsDisabled', service_instance.service.label)
      end
    end
  end
end
