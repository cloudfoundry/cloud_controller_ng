require 'repositories/service_instance_share_event_repository'

module VCAP::CloudController
  class ServiceInstanceShare
    class Error < ::StandardError
    end

    def create(service_instance, target_spaces, user_audit_info)
      validate_supported_service_type!(service_instance)
      validate_service_instance_is_shareable!(service_instance)
      validate_target_spaces!(service_instance, target_spaces)
      validate_service_instance_state!(service_instance)

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

    def error!(message)
      raise Error.new(message)
    end

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
        error!(error_msg)
      end
    end

    def validate_plan_visibility!(service_instance, space)
      unless service_instance.service_plan.visible_in_space?(space)
        error_msg = "Access to service #{service_instance.service.label} and plan #{service_instance.service_plan.name} is not enabled in #{space.organization.name}/#{space.name}."
        error!(error_msg)
      end
    end

    def validate_name_uniqueness!(service_instance, space)
      if space.service_instances.map(&:name).include?(service_instance.name)
        error_msg = "A service instance called #{service_instance.name} already exists in #{space.name}."
        error!(error_msg)
      end

      if space.service_instances_shared_from_other_spaces.map(&:name).include?(service_instance.name)
        error_msg = "A service instance called #{service_instance.name} has already been shared with #{space.name}."
        error!(error_msg)
      end
    end

    def validate_not_sharing_to_self!(service_instance, spaces)
      if spaces.include?(service_instance.space)
        error!("Unable to share service instance '#{service_instance.name}' with space '#{service_instance.space.guid}'. "\
        'Service instances cannot be shared into the space where they were created.')
      end
    end

    def validate_supported_service_type!(service_instance)
      if service_instance.route_service?
        error!('Route services cannot be shared.')
      end

      unless service_instance.managed_instance?
        error!('User-provided services cannot be shared.')
      end
    end

    def validate_service_instance_is_shareable!(service_instance)
      unless service_instance.shareable?
        error_msg = "The #{service_instance.service.label} service does not support service instance sharing."
        error!(error_msg)
      end
    end

    def validate_service_instance_state!(service_instance)
      if service_instance.create_failed?
        raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceNotFound', service_instance.name)
      elsif service_instance.create_in_progress?
        error!('Service instance is currently being created. It can be shared after its creation succeeded.')
      elsif service_instance.delete_in_progress?
        error!('The service instance is getting deleted.')
      end
    end
  end
end
