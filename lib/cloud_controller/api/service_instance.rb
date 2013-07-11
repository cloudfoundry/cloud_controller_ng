require 'services/api'
require 'cloud_controller/api/service_validator'

module VCAP::CloudController
  rest_controller :ServiceInstance do
    permissions_required do
      full Permissions::CFAdmin
      read Permissions::OrgManager
      full Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    model_class_name :ManagedServiceInstance # Must do this to be backwards compatible with actions other than enumerate


    define_attributes do
      attribute :name,  String
      to_one    :space
      to_one    :service_plan
      to_many   :service_bindings
      attribute :dashboard_url, String, exclude_in: [:create, :update]
    end

    query_parameters :name, :space_guid, :service_plan_guid, :service_binding_guid

    def before_create
      unless Models::ServicePlan.user_visible.filter(:guid => request_attrs['service_plan_guid']).count > 0
        raise Errors::NotAuthorized
      end
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
      elsif service_instance_name_errors && service_instance_name_errors.include?(:max_length)
        Errors::ServiceInstanceNameTooLong.new
      else
        Errors::ServiceInstanceInvalid.new(e.errors.full_messages)
      end
    end

    def self.not_found_exception
      Errors::ServiceInstanceNotFound
    end
  end
end
