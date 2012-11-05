# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :Domain do
    permissions_required do
      full Permissions::CFAdmin
      full Permissions::OrgManager
      read Permissions::Auditor
      read Permissions::SpaceManager
      read Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    define_attributes do
      attribute :name, String
      attribute :wildcard, Message::Boolean
      to_one    :owning_organization
    end

    query_parameters :name, :owning_organization_guid, :space_guid

    def create_quota_token_request(obj)
      return unless obj.owning_organization
      ret = quota_token_request("post", obj)
      ret[:body][:audit_data] = obj.to_hash
      ret
    end

    def update_quota_token_request(obj)
      return unless obj.owning_organization
      ret = quota_token_request("put", obj)
      ret[:body][:audit_data] = request_attrs
      ret
    end

    def delete_quota_token_request(obj)
      return unless obj.owning_organization
      quota_token_request("delete", obj)
    end

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        Errors::DomainNameTaken.new(attributes["name"])
      else
        Errors::DomainInvalid.new(e.errors.full_messages)
      end
    end

    private

    def quota_token_request(op, obj)
      {
        :path => obj.owning_organization_guid,
        :body => {
          :op           => op,
          :user_id      => user.guid,
          :object       => "domain",
          :name         => obj.name,
          :object_id    => obj.guid
        }
      }
    end
  end
end
