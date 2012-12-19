# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :ServiceInstance do
    permissions_required do
      full Permissions::CFAdmin
      read Permissions::OrgManager
      full Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    define_attributes do
      attribute :name,             String
      to_one    :space
      to_one    :service_plan
      to_many   :service_bindings
    end

    query_parameters :name, :space_guid, :service_plan_guid, :service_binding_guid

    def self.translate_validation_exception(e, attributes)
      space_and_name_errors = e.errors.on([:space_id, :name])
      quota_errors = e.errors.on(:space)
      service_plan_errors = e.errors.on(:service_plan)
      if space_and_name_errors && space_and_name_errors.include?(:unique)
        Errors::ServiceInstanceNameTaken.new(attributes["name"])
      elsif quota_errors
        Errors::ServiceInstanceQuotaExceeded.new
      elsif service_plan_errors
        Errors::ServiceInstanceServicePlanNotAllowed.new
      else
        Errors::ServiceInstanceInvalid.new(e.errors.full_messages)
      end
    end
  end
end
