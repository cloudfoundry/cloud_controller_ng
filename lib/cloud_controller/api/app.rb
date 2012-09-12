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
      attribute  :state,               String,     :default => "STOPPED", :exclude_in => :create
      to_many    :service_bindings,    :exclude_in => :create
      to_many    :routes
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

    def after_update(app, changes)
      AppStager.stage_app(app) if app.needs_staging?

      return unless app.staged?
      if changes.include?(:state)
        if app.started?
          DeaClient.start(app)
        elsif app.stopped?
          DeaClient.stop(app)
        end
      elsif changes.include?(:instances) && app.started?
        delta = changes[:instances][1] - changes[:instances][0]
        DeaClient.change_running_instances(app, delta)
      end
    end

    # This seems to be a common path to all update methods to hook this in.
    # We will otherwise have to override +update+, +add_related+, and
    # +remove_related+.
    def find_id_and_validate_access(op, guid)
      app = super
      if op == :update
        app.after_update_hook do
          next unless app.staged?
          # If it's transitioned from stopped to started, we already send out
          # the full uris in dea start message
          next if app.previous_changes.include?(:state)
          # We only need to update DEA's when a running app gets / loses uris
          if app.routes_changed? && app.started?
            # Old CC doesn't do the check on app state, because each DEA
            # drops the update uri request if the app isn't running on it
            # But I would still like to reduce message bus traffic
            DeaClient.update_uris(app)
          end
        end
      end
      app
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
