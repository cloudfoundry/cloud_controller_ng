module VCAP::CloudController
  module ServiceUpdateValidator
    class << self
      def validate!(service_instance, space:, service_plan:, service:, update_attrs:)
        if service_instance.is_a?(UserProvidedServiceInstance)
          raise CloudController::Errors::ApiError.new_from_details('UserProvidedServiceInstanceHandlerNeeded')
        end

        validate_name_update(service_instance, update_attrs)
        prevent_changing_space(space, update_attrs)
        prevent_maintenance_info_and_plan_update(service_plan, update_attrs['service_plan_guid'], update_attrs['maintenance_info'])
        validate_changing_plan(service_plan, service, service_instance, update_attrs['service_plan_guid'])
        check_plan_still_valid(service_instance, service_plan, update_attrs['service_plan_guid'])
        validate_update_of_service_parameters(service_instance, update_attrs['parameters'])
        validate_maintenance_info_update(service_plan, update_attrs['maintenance_info'])
        true
      end

      private

      def validate_update_of_service_parameters(service_instance, parameters)
        return unless parameters
        return if SecurityContext.admin?

        if ServicePlan.user_visible(SecurityContext.current_user).filter(guid: service_instance.service_plan.guid).empty?
          raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceWithInaccessiblePlanNotUpdateable', 'parameters')
        end
      end

      def validate_name_update(service_instance, update_attrs)
        return unless update_attrs['name'] && service_instance.shared?

        if update_attrs['name'] != service_instance.name
          raise CloudController::Errors::ApiError.new_from_details('SharedServiceInstanceCannotBeRenamed')
        end
      end

      def validate_maintenance_info_update(service_plan, maintenance_info)
        return unless maintenance_info

        if service_plan.maintenance_info.nil?
          raise CloudController::Errors::ApiError.new_from_details('MaintenanceInfoNotSupported')
        end

        unless VCAP::SemverValidator.valid?(maintenance_info['version'])
          raise CloudController::Errors::ApiError.new_from_details('MaintenanceInfoNotSemver')
        end
      end

      def prevent_changing_space(space, update_attrs)
        space_change_not_allowed! if space_change_requested?(update_attrs['space_guid'], space)
      end

      def prevent_maintenance_info_and_plan_update(current_plan, requested_plan_guid, requested_maintenance_info)
        if plan_update_requested?(requested_plan_guid, current_plan) && requested_maintenance_info
          raise CloudController::Errors::ApiError.new_from_details('MaintenanceInfoNotUpdatableWhenChangingPlan')
        end
      end

      def space_change_requested?(requested_space_guid, current_space)
        requested_space_guid && requested_space_guid != current_space.guid
      end

      def space_change_not_allowed!
        raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceSpaceChangeNotAllowed')
      end

      def check_plan_still_valid(service_instance, current_plan, requested_plan_guid)
        requested_plan = requested_plan_guid ? ServicePlan.find(guid: requested_plan_guid) : current_plan

        if !service_instance.valid_with_plan?(requested_plan)
          unable_to_update_to_nonfree_plan!(service_instance)
        end
      end

      def validate_changing_plan(current_plan, service, service_instance, requested_plan_guid)
        if plan_update_requested?(requested_plan_guid, current_plan)
          plan_not_updateable! unless service_allows_plan_update?(service, current_plan)

          requested_plan = ServicePlan.find(guid: requested_plan_guid)
          invalid_relation!('Plan') if invalid_plan?(requested_plan, service)

          unable_to_update_to_nonbindable_plan! if !requested_plan.bindable? && service_instance.service_bindings_dataset.any?
        end
      end

      def invalid_plan?(requested_plan, service)
        !requested_plan || plan_in_different_service?(requested_plan, service)
      end

      def plan_in_different_service?(service_plan, service)
        service_plan.service_guid != service.guid
      end

      def plan_update_requested?(requested_plan_guid, old_plan)
        requested_plan_guid && requested_plan_guid != old_plan.guid
      end

      def service_allows_plan_update?(service, current_plan)
        current_plan.plan_updateable.nil? ? service.plan_updateable : current_plan.plan_updateable
      end

      def invalid_relation!(message)
        raise CloudController::Errors::ApiError.new_from_details('InvalidRelation', message)
      end

      def unable_to_update_to_nonbindable_plan!
        raise CloudController::Errors::ApiError.new_from_details(
          'ServicePlanInvalid',
          'cannot switch to non-bindable plan when service bindings exist'
        )
      end

      def unable_to_update_to_nonfree_plan!(service_instance)
        quota_errors = service_instance.errors.on(:quota).to_a
        if quota_errors.include?(:service_instance_space_quota_exceeded)
          raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceSpaceQuotaExceeded')
        elsif quota_errors.include?(:service_instance_quota_exceeded)
          raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceQuotaExceeded')
        end

        raise CloudController::Errors::ApiError.new_from_details(
          'ServiceInstanceServicePlanNotAllowed',
          "cannot update service-instance #{service_instance.name} when quota disallows paid service plans"
        )
      end

      def plan_not_updateable!
        raise CloudController::Errors::ApiError.new_from_details('ServicePlanNotUpdateable')
      end
    end
  end
end
