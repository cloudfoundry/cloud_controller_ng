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
      service_plan_visibility  = find_guid_and_validate_access(:delete, guid, ServicePlanVisibility)
      raise_if_has_associations!(service_plan_visibility) if v2_api? && !recursive?

      model_deletion_job = Jobs::Runtime::ModelDeletion.new(ServicePlanVisibility, guid)
      delete_and_audit_job = Jobs::AuditEventJob.new(model_deletion_job, @services_event_repository, :record_service_plan_visibility_event, :delete, service_plan_visibility, {})

      if async?
        job = Jobs::Enqueuer.new(delete_and_audit_job, queue: "cc-generic").enqueue()
        [HTTP::ACCEPTED, JobPresenter.new(job).to_json]
      else
        delete_and_audit_job.perform
        [HTTP::NO_CONTENT, nil]
      end
    end

    define_messages
    define_routes
  end
end
