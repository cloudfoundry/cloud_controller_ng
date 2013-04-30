# Copyright (c) 2009-2012 VMware, Inc.

require 'services/api'

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
    end

    query_parameters :name, :space_guid, :service_plan_guid, :service_binding_guid

    def before_create
      unless Models::ServicePlan.user_visible.filter(:guid => request_attrs['service_plan_guid']).count > 0
        raise Errors::NotAuthorized
      end
    end

    def self.translate_validation_exception(e, attributes)
      space_and_name_errors = e.errors.on([:space_id, :name])
      quota_errors = e.errors.on(:space)
      service_plan_errors = e.errors.on(:service_plan)
      if space_and_name_errors && space_and_name_errors.include?(:unique)
        Errors::ServiceInstanceNameTaken.new(attributes["name"])
      elsif quota_errors
        if quota_errors.include?(:free_quota_exceeded)
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
      begin
        req = VCAP::Services::Api::HandleUpdateRequestV2.decode(body)
      rescue
        raise Errors::InvalidRequest
      end

      instance_handle = Models::ServiceInstance[:gateway_name => gateway_name]
      raise Errors::ServiceInstanceNotFound, "gateway_name=#{gateway_name}" unless instance_handle

      plan_handle = Models::ServicePlan[:id => instance_handle[:service_plan_id]]
      service_handle = Models::Service[:id => plan_handle[:service_id]]

      validate_update(service_handle[:label], service_handle[:provider], req.token)

      instance_handle.set(
        :gateway_data => req.gateway_data,
        :credentials => req.credentials,
      )
      instance_handle.save_changes
    end

    def validate_update(label, provider, token)
      raise Errors::NotAuthorized unless label && provider && token

      svc_auth_token = Models::ServiceAuthToken[
        :label    => label,
        :provider => provider,
      ]

      unless (svc_auth_token && svc_auth_token.token_matches?(token))
        logger.warn("unauthorized service offering")
        raise Errors::NotAuthorized
      end
    end

    put "/v2/service_instances/internal/:gateway_name", :update_instance
  end
end
