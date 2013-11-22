require 'services/api'

module VCAP::CloudController
  rest_controller :ServiceInstances do
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

      unless ServicePlan.user_visible(SecurityContext.current_user, SecurityContext.admin?).filter(:guid => request_attrs['service_plan_guid']).count > 0
        raise Errors::NotAuthorized
      end

      organization = requested_space.organization

      unless ServicePlan.organization_visible(organization).filter(:guid => request_attrs['service_plan_guid']).count > 0
        raise Errors::ServiceInstanceOrganizationNotAuthorized
      end

      service_instance = ManagedServiceInstance.new(request_attrs)
      validate_access(:create, service_instance, user, roles)

      unless service_instance.valid?
        raise Sequel::ValidationFailed.new(service_instance)
      end

      client = service_instance.client
      client.provision(service_instance)

      begin
        service_instance.save
      rescue => e
        begin
          # this needs to go into a retry queue
          client.deprovision(service_instance)
        rescue => deprovision_e
          logger.error "Unable to deprovision #{service_instance}: #{deprovision_e}"
        end

        raise e
      end

      [ HTTP::CREATED,
        { "Location" => "#{self.class.path}/#{service_instance.guid}" },
        serialization.render_json(self.class, service_instance, @opts)
      ]
    end

    get "/v2/service_instances/:guid", :read

    def read(guid)
      logger.debug "cc.read", :model => :ServiceInstance, :guid => guid

      obj = ServiceInstance.find(:guid => guid)

      if obj
        validate_access(:read, obj, user, roles)
      else
        raise self.class.not_found_exception.new(guid)
      end

      serialization.render_json(self.class, obj, @opts)
    end

    delete "/v2/service_instances/:guid", :delete

    def delete(guid)
      logger.debug "cc.delete", :guid => guid

      obj = ServiceInstance.find(:guid => guid)

      if obj
        validate_access(:delete, obj, user, roles)
      else
        raise self.class.not_found_exception.new(guid)
      end

      raise_if_has_associations!(obj) if v2_api? && !recursive?

      obj.destroy

      after_destroy(obj)

      [ HTTP::NO_CONTENT, nil ]
    end
  end
end
