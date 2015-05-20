require 'cloud_controller/rest_controller'
require 'actions/services/propagate_instance_credentials'

module VCAP::CloudController
  class UserProvidedServiceInstancesController < RestController::ModelController
    define_attributes do
      attribute :name, String
      attribute :credentials, Hash, default: {}
      attribute :syslog_drain_url, String, default: ''

      to_one :space
      to_many :service_bindings
    end

    def self.dependencies
      [:services_event_repository]
    end

    def inject_dependencies(dependencies)
      super
      @services_event_repository = dependencies.fetch(:services_event_repository)
    end

    def self.translate_validation_exception(e, attributes)
      space_and_name_errors = e.errors.on([:space_id, :name])
      if space_and_name_errors && space_and_name_errors.include?(:unique)
        Errors::ApiError.new_from_details('ServiceInstanceNameTaken', attributes['name'])
      else
        Errors::ApiError.new_from_details('ServiceInstanceInvalid', e.errors.full_messages)
      end
    end

    def create
      @request_attrs = decode_create_request_attrs

      logger.debug 'cc.create', model: self.class.model_class_name, attributes: request_attrs
      service_instance = create_instance(request_attrs)
      @services_event_repository.record_user_provided_service_instance_event(:create, service_instance, request_attrs)

      [
        HTTP::CREATED,
        { 'Location' => "#{self.class.path}/#{service_instance.guid}" },
        object_renderer.render_json(self.class, service_instance, @opts)
      ]
    end

    def update(guid)
      request_attrs = decode_update_request_attrs

      logger.debug 'cc.update', guid: guid, attributes: request_attrs
      raise Errors::ApiError.new_from_details('InvalidRequest') unless request_attrs

      service_instance = find_guid(guid)
      validate_access(:read_for_update, service_instance)
      validate_access(:update, service_instance)

      validate_space_not_changed(request_attrs, service_instance)
      update_instance(request_attrs, service_instance)
      propagate_instance_credentials(service_instance)

      @services_event_repository.record_user_provided_service_instance_event(:update, service_instance, request_attrs)

      [HTTP::CREATED, {}, object_renderer.render_json(self.class, service_instance, @opts)]
    end

    def delete(guid)
      service_instance = UserProvidedServiceInstance.find(guid: guid)
      raise_if_has_associations!(service_instance) if v2_api? && !recursive?

      deletion_job = Jobs::Runtime::ModelDeletion.new(ServiceInstance, guid)
      delete_and_audit_job = Jobs::AuditEventJob.new(
        deletion_job,
        @services_event_repository,
        :record_user_provided_service_instance_event,
        :delete,
        service_instance.class,
        service_instance.guid,
        {}
      )

      enqueue_deletion_job(delete_and_audit_job)
    end

    define_messages
    define_routes
  end

  private

  def decode_create_request_attrs
    json_msg = self.class::CreateMessage.decode(body)
    json_msg.extract(stringify_keys: true)
  end

  def create_instance(request_attrs)
    service_instance = nil
    UserProvidedServiceInstance.db.transaction do
      service_instance = UserProvidedServiceInstance.create_from_hash(request_attrs)
      validate_access(:create, service_instance, request_attrs)
    end
    service_instance
  end

  def decode_update_request_attrs
    json_msg = self.class::UpdateMessage.decode(body)
    json_msg.extract(stringify_keys: true)
  end

  def validate_space_not_changed(request_attrs, service_instance)
    if request_attrs['space_guid'] && request_attrs['space_guid'] != service_instance.space.guid
      raise Errors::ApiError.new_from_details('ServiceInstanceInvalid', 'cannot change space for service instance')
    end
  end

  def update_instance(request_attrs, service_instance)
    ServiceInstance.db.transaction do
      service_instance.lock!
      service_instance.update_from_hash(request_attrs)
    end
  end

  def propagate_instance_credentials(service_instance)
    PropagateInstanceCredentials.new.execute service_instance
  end
end
