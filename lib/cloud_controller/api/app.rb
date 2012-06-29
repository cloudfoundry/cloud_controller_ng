# Copyright (c) 2009-2011 VMware, Inc.

module VCAP::CloudController
  rest_controller :App do
    permissions_required do
      full Permissions::CFAdmin
    end

    define_attributes do
      attribute  :name,                String
      attribute  :production,          Message::Boolean
      to_one     :app_space
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

    query_parameters :app_space_guid, :organization_guid, :framework_guid, :runtime_guid

    def create_quota_token_request(obj)
      {
        :path => obj.app_space.organization_guid,
        :body => {
          :op           => "post",
          :user_id      => @user.guid,
          :object       => "application",
          :object_id    => obj.guid,
          :object_name  => obj.name,
          :app_space_id => obj.app_space_guid,
          :audit_data   => obj.to_hash
        }
      }
    end

    def update_quota_token_request(app)
      {
        :path => app.app_space.organization_guid,
        :body => {
          :op           => get_quota_action(app, request_attrs),
          :user_id      => @user.guid,
          :object       => "application",
          :object_id    => app.guid,
          :object_name  => app.name,
          :app_space_id => app.app_space_guid,
          :audit_data   => request_attrs
        }
      }
    end

    def delete_quota_token_request(app)
      {
        :path => app.app_space.organization_guid,
        :body => {
          :op           => "delete",
          :user_id      => @user.guid,
          :object       => "application",
          :object_id    => app.guid,
          :object_name  => app.name,
          :app_space_id => app.app_space_guid
        }
      }
    end

    def get_quota_action(app, request_attrs)
      op = "put"
      # quota treats delete as stop app
      op = "delete" if app.state == "STARTED" && request_attrs["state"] == "STOPPED"
      # quota treats post as start app
      op = "post" if app.state == "STOPPED" && request_attrs["state"] == "STARTED"
      op
    end

    def self.translate_validation_exception(e, attributes)
      app_space_and_name_errors = e.errors.on([:app_space_id, :name])
      if app_space_and_name_errors && app_space_and_name_errors.include?(:unique)
        AppNameTaken.new(attributes["name"])
      else
        AppInvalid.new(e.errors.full_messages)
      end
    end
  end
end
