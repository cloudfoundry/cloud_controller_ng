# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :AppSpace do
    permissions_required do
      full Permissions::CFAdmin
      full Permissions::OrgManager
      read   Permissions::AppSpaceManager
      update Permissions::AppSpaceManager
      read Permissions::AppSpaceDeveloper
      read Permissions::AppSpaceAuditor
    end

    define_attributes do
      attribute  :name,            String
      to_one     :organization
      to_many    :developers
      to_many    :managers
      to_many    :auditors
      to_many    :apps
      to_many    :domains
    end

    query_parameters :organization_guid, :developer_guid, :app_guid

    def create_quota_token_request(obj)
      ret = quota_token_request("create", obj)
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
      name_errors = e.errors.on([:organization_id, :name])
      if name_errors && name_errors.include?(:unique)
        AppSpaceNameTaken.new(attributes["name"])
      else
        AppSpaceInvalid.new(e.errors.full_messages)
      end
    end

    private

    def quota_token_request(op, obj)
      {
        :path => obj.organization_guid,
        :body => {
          :op           => "post",
          :user_id      => user.guid,
          :object       => "appspace",
          :object_id    => obj.guid,
          :object_name  => obj.name
        }
      }
    end
  end
end
