# Copyright (c) 2009-2011 VMware, Inc.

module VCAP::CloudController
  rest_controller :App do
    permissions_required do
      full Permissions::CFAdmin
      read Permissions::OrgManager
      read Permissions::SpaceManager
      read Permissions::SpaceManager
      full Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    define_attributes do
      attribute  :name,                String
      attribute  :production,          Message::Boolean,    :default => false
      to_one     :space
      to_one     :runtime
      to_one     :framework
      attribute  :environment_json,    Hash,       :default => {}
      attribute  :memory,              Integer,    :default => 256
      attribute  :instances,           Integer,    :default => 1
      attribute  :file_descriptors,    Integer,    :default => 256
      attribute  :disk_quota,          Integer,    :default => 256
      attribute  :state,               String,     :default => "STOPPED"
      to_many    :service_bindings,    :exclude_in => :create
    end

    query_parameters :name, :space_guid, :organization_guid, :framework_guid, :runtime_guid

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

    def after_update(app)
      AppStager.stage_app(app) if app.needs_staging?

      # TODO: this is temporary, just to validate dea integration for start
      # only.  The logic here needs to be more complex and include start, stop,
      # changing instance counts, etc
      DeaClient.start(app) if app.instances > 0
    end

    def self.translate_validation_exception(e, attributes)
      space_and_name_errors = e.errors.on([:space_id, :name])
      if space_and_name_errors && space_and_name_errors.include?(:unique)
        AppNameTaken.new(attributes["name"])
      else
        AppInvalid.new(e.errors.full_messages)
      end
    end

    private

    def quota_token_request(op, obj)
      {
        :path => obj.space.organization_guid,
        :body => {
          :op           => op,
          :user_id      => user.guid,
          :object       => "application",
          :object_id    => obj.guid,
          :object_name  => obj.name,
          :space_id     => obj.space_guid,
          :memory       => obj.memory,
          :instances    => obj.instances,
          :production   => obj.production,
          :audit_data   => obj.to_hash
        }
      }
    end
  end
end
