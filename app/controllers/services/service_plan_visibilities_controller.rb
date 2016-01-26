module VCAP::CloudController
  class ServicePlanVisibilitiesController < RestController::ModelController
    define_attributes do
      to_one :service_plan
      to_one :organization
    end

    query_parameters :organization_guid, :service_plan_guid

    def self.dependencies
      [:services_event_repository]
    end

    def inject_dependencies(dependencies)
      super
      @services_event_repository = dependencies.fetch(:services_event_repository)
    end

    def self.translate_validation_exception(e, _)
      associations_errors = e.errors.on([:organization_id, :service_plan_id])
      if associations_errors && associations_errors.include?(:unique)
        Errors::ApiError.new_from_details('ServicePlanVisibilityAlreadyExists', e.errors.full_messages)
      else
        Errors::ApiError.new_from_details('ServicePlanVisibilityInvalid', e.errors.full_messages)
      end
    end

    def create
      json_msg = self.class::CreateMessage.decode(body)

      @request_attrs = json_msg.extract(stringify_keys: true)

      logger.debug 'cc.create', model: self.class.model_class_name, attributes: request_attrs

      service_plan_visibility = nil
      model.db.transaction do
        service_plan_visibility = model.create_from_hash(request_attrs)
        validate_access(:create, service_plan_visibility, request_attrs)
      end

      @services_event_repository.record_service_plan_visibility_event(:create, service_plan_visibility, request_attrs)

      [
        HTTP::CREATED,
        { 'Location' => "#{self.class.path}/#{service_plan_visibility.guid}" },
        object_renderer.render_json(self.class, service_plan_visibility, @opts)
      ]
    end

    def update(guid)
      json_msg = self.class::UpdateMessage.decode(body)
      @request_attrs = json_msg.extract(stringify_keys: true)
      logger.debug 'cc.update', guid: guid, attributes: request_attrs
      raise InvalidRequest unless request_attrs

      service_plan_visibility = find_guid(guid)

      model.db.transaction do
        service_plan_visibility.lock!
        validate_access(:read_for_update, service_plan_visibility, request_attrs)
        service_plan_visibility.update_from_hash(request_attrs)
        validate_access(:update, service_plan_visibility, request_attrs)
      end

      @services_event_repository.record_service_plan_visibility_event(:update, service_plan_visibility, request_attrs)

      [HTTP::CREATED, object_renderer.render_json(self.class, service_plan_visibility, @opts)]
    end

    def delete(guid)
      service_plan_visibility = find_guid_and_validate_access(:delete, guid, ServicePlanVisibility)
      raise_if_has_dependent_associations!(service_plan_visibility) if v2_api? && !recursive_delete?

      model_deletion_job = Jobs::Runtime::ModelDeletion.new(ServicePlanVisibility, guid)
      delete_and_audit_job = Jobs::AuditEventJob.new(
        model_deletion_job,
        @services_event_repository,
        :record_service_plan_visibility_event,
        :delete,
        service_plan_visibility.class,
        service_plan_visibility.guid,
        {}
      )

      enqueue_deletion_job(delete_and_audit_job)
    end

    define_messages
    define_routes
  end
end
