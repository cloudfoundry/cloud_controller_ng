require 'vcap/services/api'
require 'jobs/audit_event_job'
require 'actions/services/service_instance_create'
require 'actions/services/service_instance_update'
require 'actions/services/service_instance_read'
require 'controllers/services/lifecycle/service_instance_deprovisioner'
require 'controllers/services/lifecycle/service_instance_purger'
require 'fetchers/service_instance_fetcher'
require 'fetchers/service_binding_list_fetcher'
require 'presenters/v2/service_instance_shared_to_presenter'
require 'presenters/v2/service_instance_shared_from_presenter'

module VCAP::CloudController
  class ServiceInstancesController < RestController::ModelController
    include VCAP::CloudController::LockCheck

    model_class_name :ManagedServiceInstance # Must do this to be backwards compatible with actions other than enumerate
    define_attributes do
      attribute :name, String
      attribute :parameters, Hash, default: nil
      attribute :tags, [String], default: []
      attribute :maintenance_info, Hash, default: nil, exclude_in: [:create]
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
      quota_errors                 = e.errors.on(:quota).to_a
      service_plan_errors          = e.errors.on(:service_plan).to_a
      service_instance_errors      = e.errors.on(:service_instance).to_a
      service_instance_name_errors = e.errors.on(:name).to_a
      service_instance_tags_errors = e.errors.on(:tags).to_a

      if service_instance_name_errors.include?(:unique)
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
      @request_attrs = validate_create_request
      accepts_incomplete = convert_flag_to_bool(params['accepts_incomplete'])

      service_plan = ServicePlan.first(guid: request_attrs['service_plan_guid'])
      service_plan_not_found! unless service_plan

      space = Space.filter(guid: request_attrs['space_guid']).first
      space_not_found! unless space
      organization = space.organization if space

      service_instance = ManagedServiceInstance.new(request_attrs.except('parameters'))
      validate_access(:create, service_instance)

      invalid_service_instance!(service_instance) unless service_instance.valid?

      if service_plan.broker_space_scoped?
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
      @request_attrs = validate_update_request(guid)
      accepts_incomplete = convert_flag_to_bool(params['accepts_incomplete'])

      service_instance, related_objects = ServiceInstanceFetcher.new.fetch(guid)
      not_found!(guid) if !service_instance
      if service_instance.is_a?(UserProvidedServiceInstance)
        raise CloudController::Errors::ApiError.new_from_details('UserProvidedServiceInstanceHandlerNeeded')
      end

      validate_shared_space_updateable(service_instance)
      validate_access(:read_for_update, service_instance)
      validate_access(:update, projected_service_instance(service_instance))

      ServiceUpdateValidator.validate!(
        service_instance,
        update_attrs: @request_attrs,
        space: related_objects[:space],
        service_plan: related_objects[:plan],
        service: related_objects[:service]
      )

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
    rescue LockCheck::ServiceBindingLockedError => e
      raise CloudController::Errors::ApiError.new_from_details('AsyncServiceBindingOperationInProgress', e.service_binding.app.name, e.service_binding.service_instance.name)
    end

    def read(guid)
      service_instance = find_guid_and_validate_access(:read, guid, ServiceInstance)
      object_renderer.render_json(self.class, service_instance, @opts)
    end

    def delete(guid)
      accepts_incomplete = convert_flag_to_bool(params['accepts_incomplete'])
      async = convert_flag_to_bool(params['async'])
      purge = convert_flag_to_bool(params['purge'])

      service_instance = find_service_instance(guid)

      if purge
        validate_access(:purge, service_instance)
        ServiceInstancePurger.new(@services_event_repository).purge(service_instance)
        return [HTTP::NO_CONTENT, nil]
      end

      validate_shared_space_deleteable(service_instance)
      validate_access(:delete, service_instance)

      unless recursive_delete?
        service_is_shared!(service_instance.name) if has_shares?(service_instance)

        has_associations = has_routes?(service_instance) ||
          has_bindings?(service_instance) ||
          has_keys?(service_instance)

        association_not_empty! if has_associations
      end

      deprovisioner = ServiceInstanceDeprovisioner.new(@services_event_repository)
      delete_job, warnings = deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)

      warnings.each do |warning|
        add_warning(warning)
      end

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
        HTTP::NO_CONTENT
      end
    end

    get '/v2/service_instances/:guid/permissions', :permissions

    def permissions(guid)
      service_instance = find_guid_and_validate_access(:read_permissions, guid, ServiceInstance)

      manage_permissions = @access_context.can?(:manage_permissions, service_instance)
      read_permissions = @access_context.can?(:read_permissions, service_instance)

      [HTTP::OK, JSON.generate({
        manage: manage_permissions,
        read: read_permissions
      })]
    rescue CloudController::Errors::ApiError => e
      if e.name == 'NotAuthorized'
        [HTTP::OK, JSON.generate({
          manage: false,
          read: false,
        })]
      else
        raise e
      end
    end

    get '/v2/service_instances/:guid/shared_from', :shared_from_information
    def shared_from_information(guid)
      service_instance = find_guid_and_validate_access(:read, guid, ServiceInstance)

      return HTTP::NO_CONTENT unless service_instance.shared?

      [HTTP::OK, JSON.generate(CloudController::Presenters::V2::ServiceInstanceSharedFromPresenter.new.to_hash(service_instance.space))]
    rescue CloudController::Errors::ApiError => e
      return HTTP::NOT_FOUND if e.name == 'NotAuthorized'

      raise
    end

    get '/v2/service_instances/:guid/shared_to', :enumerate_shared_to_information
    def enumerate_shared_to_information(guid)
      service_instance = find_service_instance(guid)
      validate_service_instance_access(service_instance)

      validate_access(:read, service_instance.space)

      associated_controller = VCAP::CloudController::SpacesController
      associated_path = "#{self.class.url_for_guid(guid, service_instance)}/shared_to"

      create_paginated_collection_renderer(service_instance).render_json(
        associated_controller,
        service_instance.shared_spaces_dataset,
        associated_path,
        @opts,
        {},
      )
    end

    get '/v2/service_instances/:guid/parameters', :parameters
    def parameters(guid)
      service_instance = find_guid_and_validate_access(:read, guid, ServiceInstance)
      validate_access(:read, service_instance.space)

      fetcher = ServiceInstanceRead.new

      begin
        parameters = fetcher.fetch_parameters(service_instance)

        [HTTP::OK, parameters.to_json]
      rescue ServiceInstanceRead::NotSupportedError
        raise CloudController::Errors::ApiError.new_from_details('ServiceFetchInstanceParametersNotSupported')
      end
    end

    get '/v2/service_instances/:service_instance_guid/routes/:route_guid/parameters', :route_binding_parameters
    def route_binding_parameters(service_instance_guid, route_guid)
      service_instance = find_guid_and_validate_access(:read, service_instance_guid, ServiceInstance)
      route = find_guid_and_validate_access(:read, route_guid, Route)

      route_binding = RouteBinding.find(service_instance: service_instance, route: route)
      route_binding_does_not_exist!(route_guid, service_instance_guid) unless route_binding

      fetcher = ServiceBindingRead.new

      begin
        parameters = fetcher.fetch_parameters(route_binding)

        [HTTP::OK, parameters.to_json]
      rescue ServiceBindingRead::NotSupportedError
        raise CloudController::Errors::ApiError.new_from_details('ServiceFetchBindingParametersNotSupported')
      rescue LockCheck::ServiceBindingLockedError => e
        raise CloudController::Errors::ApiError.new_from_details('AsyncServiceBindingOperationInProgress', e.service_binding.app.name, e.service_binding.service_instance.name)
      end
    end

    def self.url_for_guid(guid, object=nil)
      if object.class == UserProvidedServiceInstance
        user_provided_path = VCAP::CloudController::UserProvidedServiceInstancesController.path
        "#{user_provided_path}/#{guid}"
      else
        "#{path}/#{guid}"
      end
    end

    def get_filtered_dataset_for_enumeration(model, dataset_without_eager, query_params, opts)
      # special case: Sequel does not support querying columns not on the current table, so
      # when filtering by org_guid we have to join tables before executing the query.
      dataset = dataset_without_eager.
                eager_graph_with_options(:service_plan).
                eager_graph_with_options(:service_instance_operation)

      orig_query = opts[:q] && opts[:q].clone
      org_filters = []
      name_filters = []
      other_filters = []

      opts[:q] ||= []
      opts[:q].uniq!
      opts[:q].each do |filter|
        key, comparison, value = filter.split(/(:|>=|<=|<|>| IN )/, 2)
        if key == 'organization_guid'
          org_filters.push [key, comparison, value]
        elsif key == 'name'
          name_filters.push [:service_instances__name, comparison, value]
        else
          other_filters.push(filter)
        end
      end

      opts[:q] = other_filters
      opts.delete(:q) if opts[:q].empty?

      if other_filters.empty?
        opts.delete(:q)
      else
        opts[:q] = other_filters
      end

      dataset = super(model, dataset, query_params, opts)
      dataset = dataset.where(space_id: select_spaces_based_on_org_filters(org_filters)) unless org_filters.empty?
      dataset = select_service_instances_based_on_name_filters(dataset, name_filters) unless name_filters.empty?
      dataset
    ensure
      opts[:q] = orig_query
    end

    def add_related(guid, name, other_guid, find_model=model)
      return super(guid, name, other_guid, find_model) if name != :routes

      req_body = body.string.blank? ? '{}' : body

      json_msg = VCAP::CloudController::RouteBindingMessage.decode(req_body)
      @request_attrs = json_msg.extract(stringify_keys: true)

      bind_route(other_guid, guid)
    end

    def bind_route(route_guid, instance_guid)
      logger.debug 'cc.association.add', model: self.class.model_class_name, guid: instance_guid, assocation: :routes, other_guid: route_guid

      arbitrary_parameters = @request_attrs['parameters']

      binding_manager = ServiceInstanceBindingManager.new(self, logger)
      route_binding = binding_manager.create_route_service_instance_binding(route_guid, instance_guid, arbitrary_parameters, route_services_enabled?)

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

      HTTP::NO_CONTENT
    rescue ServiceInstanceBindingManager::RouteBindingNotFound
      route_binding_does_not_exist!(route_guid, instance_guid)
    rescue ServiceInstanceBindingManager::RouteNotFound
      raise CloudController::Errors::ApiError.new_from_details('RouteNotFound', route_guid)
    rescue ServiceInstanceBindingManager::ServiceInstanceNotFound
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceNotFound', instance_guid)
    end

    class ServiceInstanceSharedToEagerLoader
      def eager_load_dataset(spaces, _, _, _, _)
        spaces.eager(:organization)
      end
    end
    private_constant :ServiceInstanceSharedToEagerLoader

    class ServiceInstanceSharedToSerializer
      def initialize(service_instance)
        @service_instance = service_instance
      end

      def serialize(controller, space, opts, orphans=nil)
        bound_app_count = ServiceBindingListFetcher.fetch_service_instance_bindings_in_space(@service_instance.guid, space.guid).count
        CloudController::Presenters::V2::ServiceInstanceSharedToPresenter.new.to_hash(space, bound_app_count)
      end
    end
    private_constant :ServiceInstanceSharedToSerializer

    private

    def route_binding_does_not_exist!(route_guid, instance_guid)
      invalid_relation!("Route #{route_guid} is not bound to service instance #{instance_guid}.")
    end

    def find_service_instance(guid)
      find_guid(guid, ServiceInstance)
    end

    def validate_service_instance_access(service_instance)
      validate_access(:read, service_instance)
    rescue CloudController::Errors::ApiError
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceNotFound', service_instance.guid)
    end

    def create_paginated_collection_renderer(service_instance)
      VCAP::CloudController::RestController::PaginatedCollectionRenderer.new(
        ServiceInstanceSharedToEagerLoader.new,
        ServiceInstanceSharedToSerializer.new(service_instance),
        {
          max_results_per_page: config.get(:renderer, :max_results_per_page),
          default_results_per_page: config.get(:renderer, :default_results_per_page),
          max_inline_relations_depth: config.get(:renderer, :max_inline_relations_depth),
        })
    end

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

    def validate_shared_space_updateable(service_instance)
      if @access_context.can?(:read, service_instance) && @access_context.cannot?(:read, service_instance.space)
        raise CloudController::Errors::ApiError.new_from_details('SharedServiceInstanceNotUpdatableInTargetSpace')
      end
    end

    def validate_shared_space_deleteable(service_instance)
      if @access_context.can?(:read, service_instance) && @access_context.cannot?(:read, service_instance.space)
        raise CloudController::Errors::ApiError.new_from_details('SharedServiceInstanceNotDeletableInTargetSpace')
      end
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

    def service_is_shared!(name)
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceDeletionSharesExists', name)
    end

    def not_found!(guid)
      raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceNotFound', guid)
    end

    def plan_visible_to_org?(organization, service_plan)
      ServicePlan.organization_visible(organization).filter(guid: service_plan.guid).count > 0
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

    def has_shares?(service_instance)
      !service_instance.shared_spaces.empty?
    end

    def status_from_operation_state(service_instance)
      if service_instance.last_operation.state == 'in progress'
        HTTP::ACCEPTED
      else
        HTTP::CREATED
      end
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

    def select_service_instances_based_on_name_filters(dataset, name_filters)
      name_filters.each do |name_filter|
        name, comparison, value = name_filter

        dataset = if value.blank?
                    dataset.where(name => nil)
                  elsif comparison == ':'
                    dataset.where(name => value)
                  elsif comparison == ' IN '
                    dataset.where(name => value.split(','))
                  else
                    dataset.where(Sequel.lit("service_instances.name #{comparison} ?", value))
                  end
      end
      dataset
    end

    def projected_service_instance(service_instance)
      service_instance.clone.set(request_attrs.select { |k, _v| ServiceInstanceUpdate::KEYS_TO_UPDATE_CC.include? k })
    end
  end
end
