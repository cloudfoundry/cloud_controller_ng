require 'services/api'

module VCAP::CloudController
  class ServiceInstancesController < RestController::ModelController
    model_class_name :ManagedServiceInstance # Must do this to be backwards compatible with actions other than enumerate
    define_attributes do
      attribute :name,  String
      to_one    :space
      to_one    :service_plan
      to_many   :service_bindings
      attribute :dashboard_url, String, exclude_in: [:create, :update]
    end

    query_parameters :name, :space_guid, :service_plan_guid, :service_binding_guid, :gateway_name

    def requested_space
      space = Space.filter(:guid => request_attrs['space_guid']).first
      raise Errors::ServiceInstanceInvalid.new('not a valid space') unless space
      space
    end

    def self.translate_validation_exception(e, attributes)
      space_and_name_errors = e.errors.on([:space_id, :name])
      quota_errors = e.errors.on(:org)
      service_plan_errors = e.errors.on(:service_plan)
      service_instance_name_errors = e.errors.on(:name)
      if space_and_name_errors && space_and_name_errors.include?(:unique)
        Errors::ServiceInstanceNameTaken.new(attributes["name"])
      elsif quota_errors
        if quota_errors.include?(:free_quota_exceeded) ||
          quota_errors.include?(:trial_quota_exceeded)
          Errors::ServiceInstanceFreeQuotaExceeded.new
        elsif quota_errors.include?(:paid_quota_exceeded)
          Errors::ServiceInstancePaidQuotaExceeded.new
        else
          Errors::ServiceInstanceInvalid.new(e.errors.full_messages)
        end
      elsif service_plan_errors
        Errors::ServiceInstanceServicePlanNotAllowed.new
      elsif service_instance_name_errors
        if service_instance_name_errors.include?(:max_length)
          Errors::ServiceInstanceNameTooLong.new
        else
          Errors::ServiceInstanceNameInvalid.new(attributes['name'])
        end
      else
        Errors::ServiceInstanceInvalid.new(e.errors.full_messages)
      end
    end

    def self.not_found_exception
      Errors::ServiceInstanceNotFound
    end

    post "/v2/service_instances", :create
    def create
      json_msg = self.class::CreateMessage.decode(body)

      @request_attrs = json_msg.extract(:stringify_keys => true)

      logger.debug "cc.create", :model => self.class.model_class_name,
        :attributes => request_attrs

      raise InvalidRequest unless request_attrs

      raise Errors::NotAuthorized unless current_user_can_manage_plan(request_attrs['service_plan_guid'])

      organization = requested_space.organization

      unless ServicePlan.organization_visible(organization).filter(:guid => request_attrs['service_plan_guid']).count > 0
        raise Errors::ServiceInstanceOrganizationNotAuthorized
      end

      service_instance = ManagedServiceInstance.new(request_attrs)
      validate_access(:create, service_instance, user, roles)

      unless service_instance.valid?
        raise Sequel::ValidationFailed.new(service_instance)
      end

      service_instance.client.provision(service_instance)

      begin
        service_instance.save
      rescue => e
        safe_deprovision_instance(service_instance)
        raise e
      end

      [ HTTP::CREATED,
        { "Location" => "#{self.class.path}/#{service_instance.guid}" },
        serialization.render_json(self.class, service_instance, @opts)
      ]
    end

    class BulkUpdateMessage < VCAP::RestAPI::Message
      required :service_plan_guid, String
    end

    put "/v2/service_plans/:service_plan_guid/service_instances", :bulk_update
    def bulk_update(service_plan_guid)
      raise Errors::NotAuthorized unless SecurityContext.admin?

      @request_attrs = self.class::BulkUpdateMessage.decode(body).extract(:stringify_keys => true)

      existing_plan = ServicePlan.filter(:guid => service_plan_guid).first
      new_plan = ServicePlan.filter(:guid => request_attrs['service_plan_guid']).first

      if existing_plan && new_plan
        existing_plan.service_instances_dataset.update(:service_plan_id => new_plan.id)
        [HTTP::OK, {}, '']
      else
        [HTTP::BAD_REQUEST, {}, '']
      end
    end

    get "/v2/service_instances/:guid", :read
    def read(guid)
      logger.debug "cc.read", model: :ServiceInstance, guid: guid

      service_instance = find_guid_and_validate_access(:read, guid, ServiceInstance)
      serialization.render_json(self.class, service_instance, @opts)
    end

    get '/v2/service_instances/:guid/permissions', :permissions
    def permissions(guid)
      find_guid_and_validate_access(:create, guid, ServiceInstance)
      [HTTP::OK, {}, JSON.generate({ manage: true })]
    rescue Errors::NotAuthorized
      [HTTP::OK, {}, JSON.generate({ manage: false })]
    end

    delete "/v2/service_instances/:guid", :delete
    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid, ServiceInstance))
    end

    define_messages
    define_routes

    private

    def current_user_can_manage_plan(plan_guid)
      ServicePlan.user_visible(SecurityContext.current_user, SecurityContext.admin?).filter(:guid => plan_guid).count > 0
    end

    def safe_deprovision_instance(service_instance)
      # this needs to go into a retry queue
      service_instance.client.deprovision(service_instance)
    rescue => e
      logger.error "Unable to deprovision #{service_instance}: #{e}"
    end
  end
end
