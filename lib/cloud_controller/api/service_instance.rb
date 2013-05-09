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
      else
        Errors::ServiceInstanceInvalid.new(e.errors.full_messages)
      end
    end

    def update_instance(gateway_name)
      req = decode_message_body

      instance_handle = Models::ServiceInstance[:gateway_name => gateway_name]
      raise Errors::ServiceInstanceNotFound, "gateway_name=#{gateway_name}" unless instance_handle

      plan_handle = Models::ServicePlan[:id => instance_handle[:service_plan_id]]
      service_handle = Models::Service[:id => plan_handle[:service_id]]

      ServiceValidator.validate_auth_token(req.token, service_handle)
      instance_handle.update(:gateway_data => req.gateway_data, :credentials => req.credentials)
    end

    put "/v2/service_instances/internal/:gateway_name", :update_instance
  end

  def decode_message_body
    VCAP::Services::Api::HandleUpdateRequestV2.decode(body)
  rescue
    raise Errors::InvalidRequest
  end
end
