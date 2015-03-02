require 'services/api'
require 'jobs/audit_event_job'
require 'jobs/services/service_instance_deletion'
require 'controllers/services/lifecycle/service_instance_provisioner'
require 'controllers/services/lifecycle/service_instance_updater'
require 'controllers/services/lifecycle/service_instance_deprovisioner'

module VCAP::CloudController
  class ServiceInstancesController < RestController::ModelController
    model_class_name :ManagedServiceInstance # Must do this to be backwards compatible with actions other than enumerate
    define_attributes do
      attribute :name,  String
      to_one :space
      to_one :service_plan
      to_many :service_bindings
    end

    query_parameters :name, :space_guid, :service_plan_guid, :service_binding_guid, :gateway_name, :organization_guid
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
      service_instance = provisioner.create_service_instance(@request_attrs, params)

      [HTTP::CREATED,
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
      @request_attrs = self.class::UpdateMessage.decode(body).extract(stringify_keys: true)
      logger.debug 'cc.update', guid: guid, attributes: request_attrs
      raise Errors::ApiError.new_from_details('InvalidRequest') unless request_attrs

      service_instance = find_guid(guid)
      updater = ServiceInstanceUpdater.new(@services_event_repository, self, logger, @access_context)
      updater.update_service_instance(service_instance, @request_attrs, params)

      [HTTP::CREATED, {}, object_renderer.render_json(self.class, service_instance, @opts)]
    rescue ServiceInstanceUpdater::InvalidRequest
      raise Errors::ApiError.new_from_details('InvalidRequest')
    rescue ServiceInstanceUpdater::ServicePlanNotUpdatable
      raise Errors::ApiError.new_from_details('ServicePlanNotUpdateable')
    rescue ServiceInstanceUpdater::InvalidServicePlan
      raise Errors::ApiError.new_from_details('InvalidRelation', 'Plan')
    rescue ServiceInstanceUpdater::ServiceInstanceSpaceChangeNotAllowed
      raise Errors::ApiError.new_from_details('ServiceInstanceSpaceChangeNotAllowed')
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
      service_instance = find_guid(guid, ServiceInstance)
      raise_if_has_associations!(service_instance) if v2_api? && !recursive?

      deprovisioner = ServiceInstanceDeprovisioner.new(@services_event_repository, self, logger)
      service_instance, delete_job = deprovisioner.deprovision_service_instance(service_instance, params)

      if service_instance
        [HTTP::ACCEPTED, {}, object_renderer.render_json(self.class, service_instance, @opts)]
      elsif delete_job
        [HTTP::ACCEPTED, JobPresenter.new(delete_job).to_json]
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
