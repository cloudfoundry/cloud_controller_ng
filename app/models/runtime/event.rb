module VCAP::CloudController
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
      Sequel.or([
        [:space, user.audited_spaces_dataset],
        [:space, user.spaces_dataset]
      ])
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
          "instance", "index", "exit_status", "exit_description", "reason"
        )
      )
    end

    def self.record_app_update(app, actor)
      create(
        space: app.space,
        type: "audit.app.update",
        actee: app.guid,
        actee_type: "app",
        actor: actor.guid,
        actor_type: "user",
        timestamp: Time.now,
        metadata: {
          changes: app.auditable_changes,
          footprints: {
            memory: app.memory,
            instances: app.instances,
          }
        }
      )
    end

    def self.record_app_create(app, actor)
      create(
        space: app.space,
        type: "audit.app.create",
        actee: app.guid,
        actee_type: "app",
        actor: actor.guid,
        actor_type: "user",
        timestamp: Time.now,
        metadata: {
          changes: app.auditable_values,
        }
      )
    end

    def self.record_app_delete(deleting_app, actor)
      create(
        space: deleting_app.space,
        type: "audit.app.delete",
        actee: deleting_app.guid,
        actee_type: "app",
        actor: actor.guid,
        actor_type: "user",
        timestamp: Time.now,
        metadata: {
        }
      )
    end
  end
end
