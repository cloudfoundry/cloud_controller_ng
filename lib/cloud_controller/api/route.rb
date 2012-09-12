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
      to_many   :apps
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
        RouteHostTaken.new(attributes["host"])
      else
        RouteInvalid.new(e.errors.full_messages)
      end
    end

    def find_id_and_validate_access(op, guid)
      route = super
      if op == :update
        route.after_add_app_hook do |app|
          # We only need to update DEA's when a running app gets / loses uris
          if app.staged? && app.started?
            # Old CC doesn't do the check on app state, because each DEA
            # drops the update uri request if the app isn't running on it
            # But I would still like to reduce message bus traffic
            DeaClient.update_uris(app)
          end
        end
        route.after_remove_app_hook do |app|
          if app.staged? && app.started?
            DeaClient.update_uris(app)
          end
        end
      end
      route
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
