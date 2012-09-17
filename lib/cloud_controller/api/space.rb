# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :Space do
    permissions_required do
      full Permissions::CFAdmin
      full Permissions::OrgManager
      read   Permissions::SpaceManager
      update Permissions::SpaceManager
      read Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    define_attributes do
      attribute  :name,            String
      to_one     :organization
      to_many    :developers
      to_many    :managers
      to_many    :auditors
      to_many    :apps
      to_many    :domains
      to_many    :service_instances
    end

    query_parameters :name, :organization_guid, :developer_guid, :app_guid

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
      name_errors = e.errors.on([:organization_id, :name])
      if name_errors && name_errors.include?(:unique)
        Errors::SpaceNameTaken.new(attributes["name"])
      else
        Errors::SpaceInvalid.new(e.errors.full_messages)
      end
    end

    private

    def quota_token_request(op, obj)
      {
        :path => obj.organization_guid,
        :body => {
          :op           => op,
          :user_id      => user.guid,
          :object       => "space",
          :object_id    => obj.guid,
          :object_name  => obj.name
        }
      }
    end
  end
end
