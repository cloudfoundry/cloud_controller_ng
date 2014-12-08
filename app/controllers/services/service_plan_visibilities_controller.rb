module VCAP::CloudController
  class ServicePlanVisibilitiesController < RestController::ModelController
    define_attributes do
      to_one :service_plan
      to_one :organization
    end

    query_parameters :organization_guid, :service_plan_guid

    def self.dependencies
      [ :services_event_repository ]
    end

    def inject_dependencies(dependencies)
      super
      @services_event_repository = dependencies.fetch(:services_event_repository)
    end

    def self.translate_validation_exception(e, attributes)
      associations_errors = e.errors.on([:organization_id, :service_plan_id])
      if associations_errors && associations_errors.include?(:unique)
        Errors::ApiError.new_from_details("ServicePlanVisibilityAlreadyExists", e.errors.full_messages)
      else
        Errors::ApiError.new_from_details("ServicePlanVisibilityInvalid", e.errors.full_messages)
      end
    end

    def delete(guid)
      service_plan_visibility = ServicePlanVisibility.find(guid: guid)
      result = do_delete(find_guid_and_validate_access(:delete, guid))
      @services_event_repository.create_service_plan_visibility_event('audit.service_plan_visibility.delete', service_plan_visibility)
      result
    end

    define_messages
    define_routes
  end
end
