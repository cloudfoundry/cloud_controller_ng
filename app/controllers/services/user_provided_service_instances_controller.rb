require 'cloud_controller/rest_controller'
require 'actions/services/propagate_instance_credentials'

module VCAP::CloudController
  class UserProvidedServiceInstancesController < RestController::ModelController
    define_attributes do
      attribute :name, String
      attribute :credentials, Hash, default: {}
      attribute :syslog_drain_url, String, default: ''
      attribute :route_service_url, String, default: ''

      to_one :space
      to_many :service_bindings
      to_many :routes, route_for: [:get, :put, :delete]
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
      service_instance_errors = e.errors.on(:service_instance)

      if space_and_name_errors && space_and_name_errors.include?(:unique)
        Errors::ApiError.new_from_details('ServiceInstanceNameTaken', attributes['name'])
      elsif service_instance_errors.include?(:space_mismatch)
        Errors::ApiError.new_from_details('ServiceInstanceRouteBindingSpaceMismatch')
      elsif service_instance_errors.include?(:route_binding_not_allowed)
        Errors::ApiError.new_from_details('ServiceDoesNotSupportRoutes')
      elsif service_instance_errors.include?(:route_service_url_not_https)
        raise VCAP::Errors::ApiError.new_from_details('ServiceInstanceRouteServiceURLInvalid',
                                                      'Scheme for route_service_url must be https.')
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

    def add_related(guid, name, other_guid)
      return super(guid, name, other_guid) if name != :routes

      bind_route(other_guid, guid)
    end

    def add_related(guid, name, other_guid)
      return super(guid, name, other_guid) if name != :routes

      bind_route(other_guid, guid)
    end

    def remove_related(guid, name, other_guid)
      return super(guid, name, other_guid) if name != :routes

      unbind_route(other_guid, guid)
    end

    private

    def bind_route(route_guid, instance_guid)
      logger.debug 'cc.association.add', model: self.class.model_class_name, guid: instance_guid, assocation: :routes, other_guid: route_guid

      binding_manager = ServiceInstanceBindingManager.new(@services_event_repository, self, logger)
      route_binding = binding_manager.create_route_service_instance_binding(route_guid, instance_guid)

      [HTTP::CREATED, object_renderer.render_json(self.class, route_binding.service_instance, @opts)]
    rescue ServiceInstanceBindingManager::RouteNotFound
      raise VCAP::Errors::ApiError.new_from_details('RouteNotFound', route_guid)
    rescue ServiceInstanceBindingManager::RouteAlreadyBoundToServiceInstance
      raise VCAP::Errors::ApiError.new_from_details('RouteAlreadyBoundToServiceInstance')
    rescue ServiceInstanceBindingManager::ServiceInstanceNotFound
      raise VCAP::Errors::ApiError.new_from_details('ServiceInstanceNotFound', instance_guid)
    rescue ServiceInstanceBindingManager::RouteServiceRequiresDiego
      raise VCAP::Errors::ApiError.new_from_details('ServiceInstanceRouteServiceRequiresDiego')
    end

    def unbind_route(route_guid, instance_guid)
      logger.debug 'cc.association.remove', guid: instance_guid, association: :routes, other_guid: route_guid

      binding_manager = ServiceInstanceBindingManager.new(@services_event_repository, self, logger)
      binding_manager.delete_route_service_instance_binding(route_guid, instance_guid)

      [HTTP::NO_CONTENT]
    rescue ServiceInstanceBindingManager::RouteBindingNotFound
      invalid_relation!("Route #{route_guid} is not bound to service instance #{instance_guid}.")
    rescue ServiceInstanceBindingManager::RouteNotFound
      raise VCAP::Errors::ApiError.new_from_details('RouteNotFound', route_guid)
    rescue ServiceInstanceBindingManager::ServiceInstanceNotFound
      raise VCAP::Errors::ApiError.new_from_details('ServiceInstanceNotFound', instance_guid)
    end

    def invalid_relation!(message)
      raise Errors::ApiError.new_from_details('InvalidRelation', message)
    end

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
end
