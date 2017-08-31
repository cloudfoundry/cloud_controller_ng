require 'services/api'
require 'jobs/audit_event_job'
require 'actions/services/service_instance_create'
require 'actions/services/service_instance_update'
require 'controllers/services/lifecycle/service_instance_deprovisioner'
require 'controllers/services/lifecycle/service_instance_purger'
require 'fetchers/service_instance_fetcher'

module VCAP::CloudController
  class ServiceInstancesController < RestController::ModelController
    model_class_name :ManagedServiceInstance # Must do this to be backwards compatible with actions other than enumerate
    define_attributes do
      attribute :name, String
      attribute :parameters, Hash, default: nil
      attribute :tags, [String], default: []
      to_one :space
      to_one :service_plan
      to_many :service_bindings, route_for: [:get], exclude_in: [:create, :update]
      to_many :service_keys
      to_many :routes, route_for: [:get, :put, :delete], exclude_in: [:create, :update]
    end

    query_parameters :name, :space_guid, :service_plan_guid, :service_binding_guid, :gateway_name, :organization_guid, :service_key_guid
    # added :organization_guid here for readability, it is actually implemented as a search filter
    # in the #get_filtered_dataset_for_enumeration method because ModelControl does not support
    # searching on parameters that are not directly associated with the model

    preserve_query_parameters :return_user_provided_service_instances

    define_messages
    define_routes

    def self.translate_validation_exception(e, attributes)
      space_and_name_errors        = e.errors.on([:space_id, :name]).to_a
      quota_errors                 = e.errors.on(:quota).to_a
      service_plan_errors          = e.errors.on(:service_plan).to_a
      service_instance_errors      = e.errors.on(:service_instance).to_a
      service_instance_name_errors = e.errors.on(:name).to_a
      service_instance_tags_errors = e.errors.on(:tags).to_a

      if space_and_name_errors.include?(:unique)
        return CloudController::Errors::ApiError.new_from_details('ServiceInstanceNameTaken', attributes['name'])
      elsif quota_errors.include?(:service_instance_space_quota_exceeded)
        return CloudController::Errors::ApiError.new_from_details('ServiceInstanceSpaceQuotaExceeded')
      elsif quota_errors.include?(:service_instance_quota_exceeded)
        return CloudController::Errors::ApiError.new_from_details('ServiceInstanceQuotaExceeded')
      elsif service_plan_errors.include?(:paid_services_not_allowed_by_space_quota)
        return CloudController::Errors::ApiError.new_from_details('ServiceInstanceServicePlanNotAllowedBySpaceQuota')
      elsif service_plan_errors.include?(:paid_services_not_allowed_by_quota)
        return CloudController::Errors::ApiError.new_from_details('ServiceInstanceServicePlanNotAllowed')
      elsif service_instance_name_errors.include?(:max_length)
        return CloudController::Errors::ApiError.new_from_details('ServiceInstanceNameTooLong')
      elsif service_instance_name_errors.include?(:presence)
        return CloudController::Errors::ApiError.new_from_details('ServiceInstanceNameEmpty', attributes['name'])
      elsif service_instance_tags_errors.include?(:too_long)
        return CloudController::Errors::ApiError.new_from_details('ServiceInstanceTagsTooLong', attributes['name'])
      elsif service_instance_errors.include?(:route_binding_not_allowed)
        return CloudController::Errors::ApiError.new_from_details('ServiceDoesNotSupportRoutes')
      elsif service_instance_errors.include?(:space_mismatch)
        return CloudController::Errors::ApiError.new_from_details('ServiceInstanceRouteBindingSpaceMismatch')
      end

      CloudController::Errors::ApiError.new_from_details('ServiceInstanceInvalid', e.errors.full_messages)
    end

    def self.dependencies
      [:services_event_repository]
    end

    def inject_dependencies(dependencies)
      super
      @services_event_repository = dependencies.fetch(:services_event_repository)
    end

    def create
      @request_attrs     = validate_create_request
      accepts_incomplete = convert_flag_to_bool(params['accepts_incomplete'])

      service_plan = ServicePlan.first(guid: request_attrs['service_plan_guid'])
      service_plan_not_found! unless service_plan

      space = Space.filter(guid: request_attrs['space_guid']).first
      space_not_found! unless space
      organization = space.organization if space

      service_instance = ManagedServiceInstance.new(request_attrs.except('parameters'))
      validate_access(:create, service_instance)

      invalid_service_instance!(service_instance) unless service_instance.valid?

      if service_plan.broker_private?
        space_not_authorized! unless service_plan.service_broker.space == space
      else
        org_not_authorized! unless plan_visible_to_org?(organization, service_plan)
      end

      service_instance = ServiceInstanceCreate.new(@services_event_repository, logger).
                         create(request_attrs, accepts_incomplete)

      route_service_warning(service_instance) unless route_services_enabled?

      volume_service_warning(service_instance) unless volume_services_enabled?

      [status_from_operation_state(service_instance),
       { 'Location' => "#{self.class.path}/#{service_instance.guid}" },
       object_renderer.render_json(self.class, service_instance, @opts)
      ]
    end

    def update(guid)
      @request_attrs     = validate_update_request(guid)
      accepts_incomplete = convert_flag_to_bool(params['accepts_incomplete'])

      service_instance, related_objects = ServiceInstanceFetcher.new.fetch(guid)
      not_found!(guid) if !service_instance
      if service_instance.is_a?(UserProvidedServiceInstance)
        raise CloudController::Errors::ApiError.new_from_details('UserProvidedServiceInstanceHandlerNeeded')
      end

      validate_access(:read_for_update, service_instance)
      validate_access(:update, projected_service_instance(service_instance))

      validate_space_update(related_objects[:space])
      validate_plan_update(related_objects[:plan], related_objects[:service])

      update = ServiceInstanceUpdate.new(accepts_incomplete: accepts_incomplete, services_event_repository: @services_event_repository)
      update.update_service_instance(service_instance, request_attrs)

      status_code = status_from_operation_state(service_instance)
      if status_code == HTTP::ACCEPTED
        headers = { 'Location' => "#{self.class.path}/#{service_instance.guid}" }
      end

      [
        status_code,
        headers,
        object_renderer.render_json(self.class, service_instance, @opts)
      ]
    end

    def read(guid)
      service_instance = find_guid_and_validate_access(:read, guid, ServiceInstance)
      object_renderer.render_json(self.class, service_instance, @opts)
    end

    def delete(guid)
      accepts_incomplete = convert_flag_to_bool(params['accepts_incomplete'])
      async              = convert_flag_to_bool(params['async'])
      purge              = convert_flag_to_bool(params['purge'])

      service_instance = find_guid(guid, ServiceInstance)

      if purge
        validate_access(:purge, service_instance)
        ServiceInstancePurger.new(@services_event_repository).purge(service_instance)
        return [HTTP::NO_CONTENT, nil]
      end

      validate_access(:delete, service_instance)
      has_assocations = has_routes?(service_instance) ||
        has_bindings?(service_instance) ||
        has_keys?(service_instance)

      association_not_empty! if has_assocations && !recursive_delete?

      deprovisioner = ServiceInstanceDeprovisioner.new(@services_event_repository, self, logger)
      delete_job    = deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)

      if delete_job
        [
          HTTP::ACCEPTED,
          { 'Location' => "/v2/jobs/#{delete_job.guid}" },
          JobPresenter.new(delete_job).to_json
        ]
      elsif service_instance.exists?
        [
          HTTP::ACCEPTED,
          { 'Location' => "#{self.class.path}/#{service_instance.guid}" },
          object_renderer.render_json(self.class, service_instance.refresh, @opts)
        ]
      else
        [HTTP::NO_CONTENT, nil]
      end
    end

    get '/v2/service_instances/:guid/permissions', :permissions
    def permissions(guid)
      service_instance = find_guid_and_validate_access(:read_permissions, guid, ServiceInstance)

      manage_permissions = @access_context.can?(:manage_permissions, service_instance)
      read_permissions   = @access_context.can?(:read_permissions, service_instance)

      [HTTP::OK, {}, JSON.generate({
        manage: manage_permissions,
        read:   read_permissions
      })]
    rescue CloudController::Errors::ApiError => e
      if e.name == 'NotAuthorized'
        [HTTP::OK, {}, JSON.generate({
          manage: false,
          read:   false,
        })]
      else
        raise e
      end
    end

    def self.url_for_guid(guid)
      object = ServiceInstance.where(guid: guid).first

      if object.class == UserProvidedServiceInstance
        user_provided_path = VCAP::CloudController::UserProvidedServiceInstancesController.path
        return "#{user_provided_path}/#{guid}"
      else
        return "#{path}/#{guid}"
      end
    end

    def self.not_found_exception(guid, _find_model)
      CloudController::Errors::ApiError.new_from_details('ServiceInstanceNotFound', guid)
    end

    def get_filtered_dataset_for_enumeration(model, ds, qp, opts)
      # special case: Sequel does not support querying columns not on the current table, so
      # when filtering by org_guid we have to join tables before executing the query.

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
        super(model, ds, qp, opts).where(space_id: select_spaces_based_on_org_filters(org_filters))
      end
    ensure
      opts[:q] = orig_query
    end

    def add_related(guid, name, other_guid, find_model=model)
      return super(guid, name, other_guid, find_model) if name != :routes

      req_body = body.string.blank? ? '{}' : body

      json_msg       = VCAP::CloudController::RouteBindingMessage.decode(req_body)
      @request_attrs = json_msg.extract(stringify_keys: true)

      bind_route(other_guid, guid)
    end

    def bind_route(route_guid, instance_guid)
      logger.debug 'cc.association.add', model: self.class.model_class_name, guid: instance_guid, assocation: :routes, other_guid: route_guid

      arbitrary_parameters = @request_attrs['parameters']

      binding_manager = ServiceInstanceBindingManager.new(self, logger)
      route_binding   = binding_manager.create_route_service_instance_binding(route_guid, instance_guid, arbitrary_parameters, route_services_enabled?)

      [HTTP::CREATED, object_renderer.render_json(self.class, route_binding.service_instance, @opts)]
    rescue ServiceInstanceBindingManager::ServiceInstanceNotBindable
      raise CloudController::Errors::ApiError.new_from_details('UnbindableService')
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

    def remove_related(guid, name, other_guid, find_model=model)
      return super(guid, name, other_guid, find_model) if name != :routes
      unbind_route(other_guid, guid)
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

    private

    def route_services_enabled?
      @config.get(:route_services_enabled)
    end

    def volume_services_enabled?
      @config.get(:volume_services_enabled)
    end

    def route_service_warning(service_instance)
      if service_instance.route_service?
        add_warning(ServiceInstance::ROUTE_SERVICE_WARNING)
      end
    end

    def volume_service_warning(service_instance)
      if service_instance.volume_service?
        add_warning(ServiceInstance::VOLUME_SERVICE_WARNING)
      end
    end

    def validate_create_request
      @request_attrs = self.class::CreateMessage.decode(body).extract(stringify_keys: true)
      logger.debug('cc.create', model: self.class.model_class_name, attributes: request_attrs)
      invalid_request! unless request_attrs
      request_attrs
    end

    def validate_update_request(guid)
      @request_attrs = self.class::UpdateMessage.decode(body).extract(stringify_keys: true)
      logger.debug('cc.update', guid: guid, attributes: request_attrs)
      invalid_request! unless request_attrs
      request_attrs
    end

    def validate_plan_update(current_plan, service)
      requested_plan_guid = request_attrs['service_plan_guid']
      if plan_update_requested?(requested_plan_guid, current_plan)
        plan_not_updateable! if service_disallows_plan_update?(service)
        invalid_relation!('Plan') if invalid_plan?(requested_plan_guid, service)
      end
    end

    def validate_space_update(space)
      space_change_not_allowed! if space_change_requested?(request_attrs['space_guid'], space)
    end

    def invalid_service_instance!(service_instance)
      raise Sequel::ValidationFailed.new(service_instance)
    end

    def org_not_authorized!
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceOrganizationNotAuthorized')
    end

    def space_not_authorized!
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceSpaceNotAuthorized')
    end

    def space_not_found!
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceInvalid', 'not a valid space')
    end

    def service_plan_not_found!
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceInvalid', 'not a valid service plan')
    end

    def plan_not_updateable!
      raise CloudController::Errors::ApiError.new_from_details('ServicePlanNotUpdateable')
    end

    def invalid_relation!(message)
      raise CloudController::Errors::ApiError.new_from_details('InvalidRelation', message)
    end

    def invalid_request!
      raise CloudController::Errors::ApiError.new_from_details('InvalidRequest')
    end

    def association_not_empty!
      associations = 'service_bindings, service_keys, and routes'
      raise CloudController::Errors::ApiError.new_from_details('AssociationNotEmpty', associations, :service_instances)
    end

    def space_change_not_allowed!
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceSpaceChangeNotAllowed')
    end

    def not_found!(guid)
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceNotFound', guid)
    end

    def plan_visible_to_org?(organization, service_plan)
      ServicePlan.organization_visible(organization).filter(guid: service_plan.guid).count > 0
    end

    def invalid_plan?(requested_plan_guid, service)
      requested_plan = ServicePlan.find(guid: requested_plan_guid)
      plan_not_found?(requested_plan) || plan_in_different_service?(requested_plan, service)
    end

    def plan_update_requested?(requested_plan_guid, old_plan)
      requested_plan_guid && requested_plan_guid != old_plan.guid
    end

    def has_routes?(service_instance)
      !service_instance.routes.empty?
    end

    def has_bindings?(service_instance)
      !service_instance.service_bindings.empty?
    end

    def has_keys?(service_instance)
      !service_instance.service_keys.empty?
    end

    def space_change_requested?(requested_space_guid, current_space)
      requested_space_guid && requested_space_guid != current_space.guid
    end

    def plan_not_found?(service_plan)
      !service_plan
    end

    def plan_in_different_service?(service_plan, service)
      service_plan.service.guid != service.guid
    end

    def service_disallows_plan_update?(service)
      !service.plan_updateable
    end

    def status_from_operation_state(service_instance)
      if service_instance.last_operation.state == 'in progress'
        HTTP::ACCEPTED
      else
        HTTP::CREATED
      end
    end

    def convert_flag_to_bool(flag)
      raise CloudController::Errors::ApiError.new_from_details('InvalidRequest') unless ['true', 'false', nil].include? flag
      flag == 'true'
    end

    def select_spaces_based_on_org_filters(org_filters)
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

    def projected_service_instance(service_instance)
      service_instance.clone.set(request_attrs.select { |k, _v| ServiceInstanceUpdate::KEYS_TO_UPDATE_CC.include? k })
    end
  end
end
