# Copyright (c) 2009-2011 VMware, Inc.

module VCAP::CloudController
  rest_controller :App do
    permissions_required do
      full Permissions::CFAdmin
    end

    define_attributes do
      attribute  :name,                String
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
          :object       => "appspace",
          :object_id    => obj.guid,
          :object_name  => obj.name,
          :audit_data   => obj.to_json
        }
      }
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
