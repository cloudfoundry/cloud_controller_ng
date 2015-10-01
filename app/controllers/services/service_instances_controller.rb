require 'services/api'
require 'jobs/audit_event_job'
require 'actions/services/service_instance_create'
require 'actions/services/service_instance_update'
require 'controllers/services/lifecycle/service_instance_deprovisioner'
require 'controllers/services/lifecycle/service_instance_purger'
require 'queries/service_instance_fetcher'

module VCAP::CloudController
  class ServiceInstancesController < RestController::ModelController
    model_class_name :ManagedServiceInstance # Must do this to be backwards compatible with actions other than enumerate
    define_attributes do
      attribute :name, String
      attribute :parameters, Hash, default: nil
      attribute :tags, [String], default: []
      to_one :space
      to_one :service_plan
      to_many :service_bindings
      to_many :service_keys
      to_many :routes, route_for: [:get, :put, :delete], exclude_in: [:create, :update]
    end

    query_parameters :name, :space_guid, :service_plan_guid, :service_binding_guid, :gateway_name, :organization_guid, :service_key_guid
    # added :organization_guid here for readability, it is actually implemented as a search filter
    # in the #get_filtered_dataset_for_enumeration method because ModelControl does not support
    # searching on parameters that are not directly associated with the model

    def self.translate_validation_exception(e, attributes)
      space_and_name_errors = errors_on(e, [:space_id, :name])
      quota_errors = errors_on(e, :quota)
      service_plan_errors = errors_on(e, :service_plan)
      service_instance_errors = errors_on(e, :service_instance)
      service_instance_name_errors = errors_on(e, :name)
      service_instance_tags_errors = errors_on(e, :tags)

      if space_and_name_errors.include?(:unique)
        return Errors::ApiError.new_from_details('ServiceInstanceNameTaken', attributes['name'])
      elsif quota_errors.include?(:service_instance_space_quota_exceeded)
        return Errors::ApiError.new_from_details('ServiceInstanceSpaceQuotaExceeded')
      elsif quota_errors.include?(:service_instance_quota_exceeded)
        return Errors::ApiError.new_from_details('ServiceInstanceQuotaExceeded')
      elsif service_plan_errors.include?(:paid_services_not_allowed_by_space_quota)
        return Errors::ApiError.new_from_details('ServiceInstanceServicePlanNotAllowedBySpaceQuota')
      elsif service_plan_errors.include?(:paid_services_not_allowed_by_quota)
        return Errors::ApiError.new_from_details('ServiceInstanceServicePlanNotAllowed')
      elsif service_instance_name_errors.include?(:max_length)
        return Errors::ApiError.new_from_details('ServiceInstanceNameTooLong')
      elsif service_instance_name_errors.include?(:presence)
        return Errors::ApiError.new_from_details('ServiceInstanceNameEmpty', attributes['name'])
      elsif service_instance_tags_errors.include?(:too_long)
        return Errors::ApiError.new_from_details('ServiceInstanceTagsTooLong')
      elsif service_instance_errors.include?(:route_binding_not_allowed)
        return Errors::ApiError.new_from_details('ServiceDoesNotSupportRoutes')
      elsif service_instance_errors.include?(:space_mismatch)
        return Errors::ApiError.new_from_details('ServiceInstanceRouteBindingSpaceMismatch')
      end

      Errors::ApiError.new_from_details('ServiceInstanceInvalid', e.errors.full_messages)
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
      space = Space.filter(guid: request_attrs['space_guid']).first
      organization = space.organization if space

      service_plan_not_found! unless service_plan

      service_instance = ManagedServiceInstance.new(request_attrs.except('parameters'))
      validate_access(:create, service_instance)

      invalid_service_instance!(service_instance) unless service_instance.valid?
      space_not_found! unless space

      if service_plan.broker_private?
        space_not_authorized! unless (service_plan.service_broker.space == space)
      else
        org_not_authorized! unless plan_visible_to_org?(organization, service_plan)
      end

      service_instance = ServiceInstanceCreate.new(@services_event_repository, logger).
                             create(request_attrs, accepts_incomplete)

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

      validate_access(:read_for_update, service_instance)
      validate_access(:update, service_instance)

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
      logger.debug 'cc.read', model: :ServiceInstance, guid: guid

      service_instance = find_guid_and_validate_access(:read, guid, ServiceInstance)
      object_renderer.render_json(self.class, service_instance, @opts)
    end

    def delete(guid)
      accepts_incomplete = convert_flag_to_bool(params['accepts_incomplete'])
      async = convert_flag_to_bool(params['async'])
      purge = convert_flag_to_bool(params['purge'])

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

      association_not_empty! if has_assocations && !recursive?

      deprovisioner = ServiceInstanceDeprovisioner.new(@services_event_repository, self, logger)
      delete_job = deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)

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
      find_guid_and_validate_access(:read_permissions, guid, ServiceInstance)
      [HTTP::OK, {}, JSON.generate({ manage: true })]
    rescue Errors::ApiError => e
      if e.name == 'NotAuthorized'
        [HTTP::OK, {}, JSON.generate({ manage: false })]
      else
        raise e
      end
    end

    class BulkUpdateMessage < VCAP::RestAPI::Message
      required :service_plan_guid, String
    end

    put '/v2/service_plans/:service_plan_guid/service_instances', :bulk_update
    def bulk_update(existing_service_plan_guid)
      raise Errors::ApiError.new_from_details('NotAuthorized') unless SecurityContext.admin?

      @request_attrs = self.class::BulkUpdateMessage.decode(body).extract(stringify_keys: true)

      existing_plan = ServicePlan.filter(guid: existing_service_plan_guid).first
      new_plan = ServicePlan.filter(guid: request_attrs['service_plan_guid']).first

      if existing_plan && new_plan
        changed_count = existing_plan.service_instances_dataset.update(service_plan_id: new_plan.id)
        [HTTP::OK, {}, { changed_count: changed_count }.to_json]
      else
        [HTTP::BAD_REQUEST, {}, '']
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

    def self.not_found_exception(guid)
      Errors::ApiError.new_from_details('ServiceInstanceNotFound', guid)
    end

    def get_filtered_dataset_for_enumeration(model, ds, qp, opts)
      single_filter = opts[:q][0] if opts[:q]

      if single_filter && single_filter.start_with?('organization_guid')
        org_guid = single_filter.split(':')[1]

        Query.
          filtered_dataset_from_query_params(model, ds, qp, { q: '' }).
          select_all(:service_instances).
          left_join(:spaces, id: :service_instances__space_id).
          left_join(:organizations, id: :spaces__organization_id).
          where(organizations__guid: org_guid)
      else
        super(model, ds, qp, opts)
      end
    end

    define_messages
    define_routes

    def add_related(guid, name, other_guid)
      return super(guid, name, other_guid) if name != :routes

      bind_route(guid, other_guid)
    end

    def bind_route(instance_guid, route_guid)
      logger.debug 'cc.association.add', guid: instance_guid, assocation: :routes, other_guid: route_guid
      @request_attrs = { route: route_guid }

      route = Route.find(guid: route_guid)
      raise Errors::ApiError.new_from_details('RouteNotFound', route_guid) unless route
      raise Errors::ApiError.new_from_details('RouteAlreadyBoundToServiceInstance') if route.service_instance

      instance = find_guid(instance_guid)

      before_update(instance)

      binding_manager = ServiceInstanceBindingManager.new(@services_event_repository, self, logger)
      binding_manager.create_route_service_instance_binding(route, instance)

      after_update(instance)

      [HTTP::CREATED, object_renderer.render_json(self.class, instance, @opts)]
    rescue ServiceInstanceBindingManager::ServiceInstanceNotBindable
      raise VCAP::Errors::ApiError.new_from_details('UnbindableService')
    end

    def remove_related(guid, name, other_guid)
      return super(guid, name, other_guid) if name != :routes

      unbind_route(guid, other_guid)
    end

    def unbind_route(instance_guid, route_guid)
      logger.debug 'cc.association.remove', guid: instance_guid, association: :routes, other_guid: route_guid

      instance = find_guid(instance_guid)
      route = find_guid(route_guid, Route)
      binding = RouteBinding.find(service_instance: instance, route: route)
      invalid_relation!("Route #{route_guid} is not bound to service instance #{instance_guid}.") if binding.nil?

      binding_manager = ServiceInstanceBindingManager.new(@services_event_repository, self, logger)
      binding_manager.delete_route_service_instance_binding(binding)

      [HTTP::NO_CONTENT]
    end

    private

    def validate_create_request
      request_attrs = self.class::CreateMessage.decode(body).extract(stringify_keys: true)
      logger.debug('cc.create', model: self.class.model_class_name, attributes: request_attrs)
      invalid_request! unless request_attrs
      request_attrs
    end

    def validate_update_request(guid)
      request_attrs = self.class::UpdateMessage.decode(body).extract(stringify_keys: true)
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
      raise Errors::ApiError.new_from_details('ServiceInstanceOrganizationNotAuthorized')
    end

    def space_not_authorized!
      raise Errors::ApiError.new_from_details('ServiceInstanceSpaceNotAuthorized')
    end

    def space_not_found!
      raise Errors::ApiError.new_from_details('ServiceInstanceInvalid', 'not a valid space')
    end

    def service_plan_not_found!
      raise Errors::ApiError.new_from_details('ServiceInstanceInvalid', 'not a valid service plan')
    end

    def plan_not_updateable!
      raise Errors::ApiError.new_from_details('ServicePlanNotUpdateable')
    end

    def invalid_relation!(message)
      raise Errors::ApiError.new_from_details('InvalidRelation', message)
    end

    def invalid_request!
      raise Errors::ApiError.new_from_details('InvalidRequest')
    end

    def association_not_empty!
      asscociations = 'service_bindings, service_keys, and routes'
      raise VCAP::Errors::ApiError.new_from_details('AssociationNotEmpty', asscociations, :service_instances)
    end

    def space_change_not_allowed!
      raise Errors::ApiError.new_from_details('ServiceInstanceSpaceChangeNotAllowed')
    end

    def not_found!(guid)
      raise Errors::ApiError.new_from_details('ServiceInstanceNotFound', guid)
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
        state = HTTP::ACCEPTED
      else
        state = HTTP::CREATED
      end
      state
    end

    def convert_flag_to_bool(flag)
      raise Errors::ApiError.new_from_details('InvalidRequest') unless ['true', 'false', nil].include? flag
      flag == 'true'
    end

    def self.errors_on(e, fields)
      e.errors.on(fields).to_a
    end
  end
end
