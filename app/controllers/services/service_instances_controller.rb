require 'services/api'
require 'jobs/audit_event_job'
require 'controllers/services/lifecycle/service_instance_provisioner'
# require 'controllers/services/lifecycle/service_instance_updater'
require 'actions/service_instance_update'
require 'controllers/services/lifecycle/service_instance_deprovisioner'

module VCAP::CloudController
  class ServiceInstancesController < RestController::ModelController
    model_class_name :ManagedServiceInstance # Must do this to be backwards compatible with actions other than enumerate
    define_attributes do
      attribute :name, String
      attribute :parameters, Hash, default: nil
      to_one :space
      to_one :service_plan
      to_many :service_bindings
      to_many :service_keys
    end

    query_parameters :name, :space_guid, :service_plan_guid, :service_binding_guid, :gateway_name, :organization_guid, :service_key_guid
    # added :organization_guid here for readability, it is actually implemented as a search filter
    # in the #get_filtered_dataset_for_enumeration method because ModelControl does not support
    # searching on parameters that are not directly associated with the model

    def self.translate_validation_exception(e, attributes)
      space_and_name_errors = e.errors.on([:space_id, :name])
      quota_errors = e.errors.on(:quota)
      service_plan_errors = e.errors.on(:service_plan)
      service_instance_name_errors = e.errors.on(:name)
      if space_and_name_errors && space_and_name_errors.include?(:unique)
        return Errors::ApiError.new_from_details('ServiceInstanceNameTaken', attributes['name'])
      elsif quota_errors
        if quota_errors.include?(:service_instance_space_quota_exceeded)
          return Errors::ApiError.new_from_details('ServiceInstanceSpaceQuotaExceeded')
        elsif quota_errors.include?(:service_instance_quota_exceeded)
          return Errors::ApiError.new_from_details('ServiceInstanceQuotaExceeded')
        end
      elsif service_plan_errors
        if service_plan_errors.include?(:paid_services_not_allowed_by_space_quota)
          return Errors::ApiError.new_from_details('ServiceInstanceServicePlanNotAllowedBySpaceQuota')
        elsif service_plan_errors.include?(:paid_services_not_allowed_by_quota)
          return Errors::ApiError.new_from_details('ServiceInstanceServicePlanNotAllowed')
        end
      elsif service_instance_name_errors
        if service_instance_name_errors.include?(:max_length)
          return Errors::ApiError.new_from_details('ServiceInstanceNameTooLong')
        else
          return Errors::ApiError.new_from_details('ServiceInstanceNameEmpty', attributes['name'])
        end
      end

      Errors::ApiError.new_from_details('ServiceInstanceInvalid', e.errors.full_messages)
    end

    def self.not_found_exception(guid)
      Errors::ApiError.new_from_details('ServiceInstanceNotFound', guid)
    end

    def self.dependencies
      [:services_event_repository]
    end

    def inject_dependencies(dependencies)
      super
      @services_event_repository = dependencies.fetch(:services_event_repository)
    end

    def create
      json_msg = self.class::CreateMessage.decode(body)
      @request_attrs = json_msg.extract(stringify_keys: true)
      logger.debug 'cc.create', model: self.class.model_class_name, attributes: request_attrs

      provisioner = ServiceInstanceProvisioner.new(
        @services_event_repository,
        self,
        logger,
        @access_context
      )
      accepts_incomplete = convert_flag_to_bool(params['accepts_incomplete'])
      service_instance = provisioner.create_service_instance(@request_attrs, accepts_incomplete)

      if service_instance.last_operation.state == 'in progress'
        state = HTTP::ACCEPTED
      else
        state = HTTP::CREATED
      end

      [state,
       { 'Location' => "#{self.class.path}/#{service_instance.guid}" },
       object_renderer.render_json(self.class, service_instance, @opts)
      ]
    rescue ServiceInstanceProvisioner::Unauthorized
      raise Errors::ApiError.new_from_details('NotAuthorized')
    rescue ServiceInstanceProvisioner::ServiceInstanceCannotAccessServicePlan
      raise Errors::ApiError.new_from_details('ServiceInstanceOrganizationNotAuthorized')
    rescue ServiceInstanceProvisioner::InvalidRequest
      raise Errors::ApiError.new_from_details('InvalidRequest')
    rescue ServiceInstanceProvisioner::InvalidServicePlan
      raise Errors::ApiError.new_from_details('ServiceInstanceInvalid', 'not a valid service plan')
    rescue ServiceInstanceProvisioner::InvalidSpace
      raise Errors::ApiError.new_from_details('ServiceInstanceInvalid', 'not a valid space')
    end

    def update(guid)
      # User input validation
      @request_attrs = self.class::UpdateMessage.decode(body).extract(stringify_keys: true)
      logger.debug 'cc.update', guid: guid, attributes: request_attrs
      invalid_request! unless request_attrs
      accepts_incomplete = convert_flag_to_bool(params['accepts_incomplete'])
      requested_plan_guid = request_attrs['service_plan_guid']

      # Fetcher
      service_instance = find_guid(guid)
      current_plan = service_instance.service_plan
      service = current_plan.service
      space = service_instance.space
      requested_plan = ServicePlan.find(guid: requested_plan_guid)

      # Permission Validation
      validate_access(:read_for_update, service_instance)
      validate_access(:update, service_instance)

      # Business Validation
      space_change_not_allowed! if space_change_requested?(request_attrs['space_guid'], space)
      if plan_update_requested?(requested_plan_guid, current_plan)
        plan_not_updateable! if service_disallows_plan_update?(service)
        invalid_relation! if invalid_plan?(requested_plan, service)
      end

      update = ServiceInstanceUpdate.new(accepts_incomplete: accepts_incomplete,
                                         services_event_repository: @services_event_repository)
      update.update_service_instance(service_instance, request_attrs)

      if service_instance.last_operation.state == 'in progress'
        state = HTTP::ACCEPTED
      else
        state = HTTP::CREATED
      end

      [state, {}, object_renderer.render_json(self.class, service_instance, @opts)]
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

    def read(guid)
      logger.debug 'cc.read', model: :ServiceInstance, guid: guid

      service_instance = find_guid_and_validate_access(:read, guid, ServiceInstance)
      object_renderer.render_json(self.class, service_instance, @opts)
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

    def delete(guid)
      # Input validation
      accepts_incomplete = convert_flag_to_bool(params['accepts_incomplete'])
      async = convert_flag_to_bool(params['async'])

      # Fetcher
      service_instance = find_guid(guid, ServiceInstance)

      # Permission validation
      validate_access(:delete, service_instance)

      # Business validation
      raise_if_has_associations!(service_instance) if v2_api? && !recursive?
      association_not_empty!(:service_bindings) if has_bindings?(service_instance) && !recursive?
      association_not_empty!(:service_keys) if has_keys?(service_instance) && !recursive?

      deprovisioner = ServiceInstanceDeprovisioner.new(@services_event_repository, self, logger)
      delete_job = deprovisioner.deprovision_service_instance(service_instance, accepts_incomplete, async)

      if delete_job
        [HTTP::ACCEPTED, JobPresenter.new(delete_job).to_json]
      elsif service_instance.exists?
        [HTTP::ACCEPTED, {}, object_renderer.render_json(self.class, service_instance.refresh, @opts)]
      else
        [HTTP::NO_CONTENT, nil]
      end
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

    private

    def invalid_plan?(requested_plan, service)
      plan_not_found?(requested_plan) || plan_in_different_service?(requested_plan, service)
    end

    def plan_update_requested?(requested_plan_guid, old_plan)
      requested_plan_guid && requested_plan_guid != old_plan.guid
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

    def plan_not_updateable!
      raise Errors::ApiError.new_from_details('ServicePlanNotUpdateable')
    end

    def invalid_relation!
      raise Errors::ApiError.new_from_details('InvalidRelation', 'Plan')
    end

    def invalid_request!
      raise Errors::ApiError.new_from_details('InvalidRequest')
    end

    def association_not_empty!(association)
      raise VCAP::Errors::ApiError.new_from_details('AssociationNotEmpty', association, :service_instances)
    end

    def space_change_not_allowed!
      raise Errors::ApiError.new_from_details('ServiceInstanceSpaceChangeNotAllowed')
    end

    def convert_flag_to_bool(flag)
      raise Errors::ApiError.new_from_details('InvalidRequest') unless ['true', 'false', nil].include? flag
      flag == 'true'
    end

    def raise_if_has_associations!(obj)
      associations = obj.class.associations.select do |association|
        association_action = obj.class.association_dependencies_hash[association]
        if association_action == :destroy && association != :service_instance_operation
          obj.has_one_to_many?(association) || obj.has_one_to_one?(association)
        end
      end

      if associations.any?
        raise VCAP::Errors::ApiError.new_from_details('AssociationNotEmpty', associations.join(', '), obj.class.table_name)
      end
    end
  end
end
