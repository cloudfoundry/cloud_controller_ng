module VCAP::CloudController::Models
  class Event < Sequel::Model
    plugin :serialization

    many_to_one :space

    def validate
      validates_presence :type
      validates_presence :timestamp
      validates_presence :actor
      validates_presence :actor_type
      validates_presence :actee
      validates_presence :actee_type
    end

    serialize_attributes :json, :metadata

    export_attributes :type, :actor, :actor_type, :actee,
      :actee_type, :timestamp, :metadata, :space_guid

    def self.user_visibility_filter(user)
      user_visibility_filter_with_admin_override(
        # buckle up
        Sequel.|(
          {
            :space => user.audited_spaces_dataset
          }, {
            :space => user.spaces_dataset
          }
        )
      )
    end

    def self.create_app_exit_event(app, droplet_exited_payload)
      create(
        space: app.space,
        type: "app.crash",
        actee: app.guid,
        actee_type: "app",
        actor: app.guid,
        actor_type: "app",
        timestamp: Time.now,
        metadata: droplet_exited_payload.slice(
          :instance, :index, :exit_status, :exit_description, :reason
        )
      )
    end

    def self.record_app_update(actee, actor)
      create(
        space: actee.space,
        type: "app.update",
        actee: actee.guid,
        actee_type: "app",
        actor: actor.guid,
        actor_type: "user",
        timestamp: Time.now,
        metadata: {
          changes: actee.auditable_changes
        }
      )
    end

    def self.record_app_create(actee, actor)
      create(
        space: actee.space,
        type: "app.create",
        actee: actee.guid,
        actee_type: "app",
        actor: actor.guid,
        actor_type: "user",
        timestamp: Time.now,
        metadata: {
          changes: actee.auditable_values
        }
      )
    end
  end
end