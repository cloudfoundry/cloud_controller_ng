# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :ServiceInstance do
    permissions_required do
      full Permissions::CFAdmin
    end

    define_attributes do
      attribute :name,             String
      to_one    :app_space
      to_one    :service_plan
      to_many   :service_bindings
      attribute :credentials,      Hash
      attribute :vendor_data,      String, :default => "" # FIXME: notation for access override here
    end

    query_parameters :app_space_guid, :service_plan_guid, :service_binding_guid

    def create_quota_token_request(obj)
      ret = quota_token_request("post", obj)
      ret[:body][:audit_data] = obj.to_hash
      ret
    end

    def update_quota_token_request(obj)
      ret = quota_token_request("put", obj)
      ret[:body][:audit_data] = obj.to_hash
      ret
    end

    def delete_quota_token_request(obj)
       quota_token_request("delete", obj)
    end

    def self.translate_validation_exception(e, attributes)
      app_space_and_name_errors = e.errors.on([:app_space_id, :name])
      if app_space_and_name_errors && app_space_and_name_errors.include?(:unique)
        ServiceInstanceNameTaken.new(attributes["name"])
      else
        ServiceInstanceInvalid.new(e.errors.full_messages)
      end
    end

    private

    def quota_token_request(op, obj)
      {
        :path => obj.app_space.organization_guid,
        :body => {
          :op           => op,
          :user_id      => @user.guid,
          :object       => "service",
          :object_id    => obj.guid,
          :app_space_id => obj.app_space.guid,
          :object_name  => obj.name,
          :plan_name    => obj.service_plan.name,
          :service_label => obj.service_plan.service.label,
          :service_provider => obj.service_plan.service.provider,
          :service_version => obj.service_plan.service.version
        }
      }
    end

  end
end
