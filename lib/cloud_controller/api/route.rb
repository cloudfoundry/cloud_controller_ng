# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :Route do
    permissions_required do
      full Permissions::CFAdmin
      full Permissions::OrgManager
      read Permissions::Auditor
      full Permissions::SpaceManager
      full Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    define_attributes do
      attribute :host, String
      to_one    :domain
      to_one    :organization
    end

    query_parameters :host, :domain_guid

    def create_quota_token_request(obj)
      ret = quota_token_request("post", obj)
      ret[:body][:audit_data] = obj.to_hash
      ret
    end

    def update_quota_token_request(obj)
      ret = quota_token_request("put", obj)
      ret[:body][:audit_data] = request_attrs
      ret
    end

    def delete_quota_token_request(obj)
      quota_token_request("delete", obj)
    end

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on([:host, :domain_id])
      if name_errors && name_errors.include?(:unique)
        Errors::RouteHostTaken.new(attributes["host"])
      else
        Errors::RouteInvalid.new(e.errors.full_messages)
      end
    end

    private

    def quota_token_request(op, obj)
      {
        :path => obj.organization_guid,
        :body => {
          :op           => op,
          :user_id      => user.guid,
          :object       => "route",
          :host         => obj.host,
          :object_id    => obj.guid,
          :domain_id    => obj.domain.guid
        }
      }
    end
  end
end
