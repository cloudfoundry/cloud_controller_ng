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

    query_parameters :name, :space_guid, :organization_guid

    CENSORED_FIELDS = ['credentials'].freeze
    CENSORED_MESSAGE = 'PRIVATE_DATA_HIDDEN'.freeze

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
        CloudController::Errors::ApiError.new_from_details('ServiceInstanceNameTaken', attributes['name'])
      elsif service_instance_errors && service_instance_errors.include?(:space_mismatch)
        CloudController::Errors::ApiError.new_from_details('ServiceInstanceRouteBindingSpaceMismatch')
      elsif service_instance_errors && service_instance_errors.include?(:route_binding_not_allowed)
        CloudController::Errors::ApiError.new_from_details('ServiceDoesNotSupportRoutes')
      elsif service_instance_errors && service_instance_errors.include?(:route_service_url_not_https)
        raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceRouteServiceURLInvalid',
                                                      'Scheme for route_service_url must be https.')
      elsif service_instance_errors && service_instance_errors.include?(:route_service_url_invalid)
        raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceRouteServiceURLInvalid',
                                                      'route_service_url is invalid.')
      else
        CloudController::Errors::ApiError.new_from_details('ServiceInstanceInvalid', e.errors.full_messages)
      end
    end

    def create
      @request_attrs = decode_create_request_attrs

      censored_attrs = censor(@request_attrs)
      logger.debug 'cc.create', model: self.class.model_class_name, attributes: censored_attrs
      service_instance = create_instance(request_attrs)
      @services_event_repository.record_user_provided_service_instance_event(:create, service_instance, request_attrs)
      route_service_warning(service_instance) unless route_services_enabled?

      [
        HTTP::CREATED,
        { 'Location' => "#{self.class.path}/#{service_instance.guid}" },
        object_renderer.render_json(self.class, service_instance, @opts)
      ]
    end

    def update(guid)
      @request_attrs = decode_update_request_attrs

      censored_attrs = censor(@request_attrs)
      logger.debug 'cc.update', guid: guid, attributes: censored_attrs
      raise CloudController::Errors::ApiError.new_from_details('InvalidRequest') unless request_attrs

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
      raise_if_has_dependent_associations!(service_instance) if v2_api? && !recursive_delete?

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

    def get_filtered_dataset_for_enumeration(model, ds, qp, opts)
      # special case: we cannot query columns in the org table from the UPSI
      # table, so we have to join w/ orgs and then select on the spaces of the org
      orig_query = opts[:q] && opts[:q].clone
      org_filters = []

      opts[:q] ||= []
      opts[:q].each do |filter|
        key, comparison, value = filter.split(/(:|>=|<=|<|>| IN )/, 2)
        org_filters.push [key, comparison, value] if key == 'organization_guid'
      end

      opts[:q] -= org_filters.map(&:join)
      opts.delete(:q) if opts[:q].blank?

      if org_filters.empty?
        super(model, ds, qp, opts)
      else
        super(model, ds, qp, opts).where(space_id: select_on_org_filters_using_spaces(org_filters))
      end
    ensure
      opts[:q] = orig_query
    end

    def select_on_org_filters_using_spaces(org_filters)
      space_ids = Space.select(:spaces__id).left_join(:organizations, id: :spaces__organization_id)
      org_filters.each do |_, comparison, value|
        space_ids = if value.blank?
                      space_ids.where(organizations__guid: nil)
                    elsif comparison == ':'
                      space_ids.where(organizations__guid: value)
                    elsif comparison == ' IN '
                      space_ids.where(organizations__guid: value.split(','))
                    else
                      space_ids.where(Sequel.lit("organizations.guid #{comparison} ?", value))
                    end
      end

      space_ids
    end

    define_messages
    define_routes

    def add_related(guid, name, other_guid, find_model=model)
      return super(guid, name, other_guid, find_model) if name != :routes

      bind_route(other_guid, guid)
    end

    def remove_related(guid, name, other_guid, find_model=model)
      return super(guid, name, other_guid, find_model) if name != :routes

      unbind_route(other_guid, guid)
    end

    private

    def route_services_enabled?
      @config.get(:route_services_enabled)
    end

    def route_service_warning(service_instance)
      if service_instance.route_service?
        add_warning(ServiceInstance::ROUTE_SERVICE_WARNING)
      end
    end

    def bind_route(route_guid, instance_guid)
      logger.debug 'cc.association.add', model: self.class.model_class_name, guid: instance_guid, assocation: :routes, other_guid: route_guid

      binding_manager = ServiceInstanceBindingManager.new(self, logger)
      route_binding = binding_manager.create_route_service_instance_binding(route_guid, instance_guid, {}, route_services_enabled?)

      [HTTP::CREATED, object_renderer.render_json(self.class, route_binding.service_instance, @opts)]
    rescue ServiceInstanceBindingManager::RouteNotFound
      raise CloudController::Errors::ApiError.new_from_details('RouteNotFound', route_guid)
    rescue ServiceInstanceBindingManager::ServiceInstanceAlreadyBoundToSameRoute
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceAlreadyBoundToSameRoute')
    rescue ServiceInstanceBindingManager::RouteAlreadyBoundToServiceInstance
      raise CloudController::Errors::ApiError.new_from_details('RouteAlreadyBoundToServiceInstance')
    rescue ServiceInstanceBindingManager::ServiceInstanceNotFound
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceNotFound', instance_guid)
    rescue ServiceInstanceBindingManager::RouteServiceRequiresDiego
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceRouteServiceRequiresDiego')
    rescue ServiceInstanceBindingManager::RouteServiceDisabled
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceRouteServiceDisabled')
    end

    def unbind_route(route_guid, instance_guid)
      logger.debug 'cc.association.remove', guid: instance_guid, association: :routes, other_guid: route_guid

      binding_manager = ServiceInstanceBindingManager.new(self, logger)
      binding_manager.delete_route_service_instance_binding(route_guid, instance_guid)

      [HTTP::NO_CONTENT]
    rescue ServiceInstanceBindingManager::RouteBindingNotFound
      invalid_relation!("Route #{route_guid} is not bound to service instance #{instance_guid}.")
    rescue ServiceInstanceBindingManager::RouteNotFound
      raise CloudController::Errors::ApiError.new_from_details('RouteNotFound', route_guid)
    rescue ServiceInstanceBindingManager::ServiceInstanceNotFound
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceNotFound', instance_guid)
    end

    def invalid_relation!(message)
      raise CloudController::Errors::ApiError.new_from_details('InvalidRelation', message)
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
        raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceInvalid', 'cannot change space for service instance')
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

    def censor(request_attrs)
      request_attrs.dup.tap do |changes|
        CENSORED_FIELDS.map(&:to_s).each do |censored|
          changes[censored] = CENSORED_MESSAGE if changes.key?(censored)
        end
      end
    end
  end
end
