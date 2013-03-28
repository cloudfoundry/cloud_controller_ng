# Copyright (c) 2009-2012 VMware, Inc.

require 'services/api'

module VCAP::CloudController
  rest_controller :ServiceBinding do
    permissions_required do
      full Permissions::CFAdmin
      read Permissions::OrgManager
      create Permissions::SpaceDeveloper
      read   Permissions::SpaceDeveloper
      delete Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    define_attributes do
      to_one    :app
      to_one    :service_instance
    end

    query_parameters :app_guid, :service_instance_guid

    def self.translate_validation_exception(e, attributes)
      unique_errors = e.errors.on([:app_id, :service_instance_id])
      if unique_errors && unique_errors.include?(:unique)
        Errors::ServiceBindingAppServiceTaken.new(
          "#{attributes["app_guid"]} #{attributes["service_instance_guid"]}")
      else
        Errors::ServiceBindingInvalid.new(e.errors.full_messages)
      end
    end

    def update_binding(gateway_name)
      begin
        req = VCAP::Services::Api::HandleUpdateRequestV2.decode(body)
      rescue
        raise Errors::InvalidRequest
      end

      binding_handle = Models::ServiceBinding[:gateway_name => gateway_name]
      raise Errors::ServiceBindingNotFound, "gateway_name=#{gateway_name}" unless binding_handle

      instance_handle = Models::ServiceInstance[:id => binding_handle[:service_instance_id]]
      plan_handle = Models::ServicePlan[:id => instance_handle[:service_plan_id]]
      service_handle = Models::Service[:id => plan_handle[:service_id]]

      validate_update(service_handle[:label], service_handle[:provider], req.token)

      binding_handle.set(
        :gateway_data => req.gateway_data,
        :credentials  => req.credentials,
      )
      binding_handle.save_changes
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

    put "/v2/service_bindings/internal/:gateway_name", :update_binding
  end
end
