module VCAP::CloudController
  module Repositories
    module Runtime
      class AppEventRepository
        def create_app_exit_event(app, droplet_exited_payload)
          Loggregator.emit(app.guid, "App instance exited with guid #{app.guid} payload: #{droplet_exited_payload}")

          Event.create(
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

        def record_app_update(app, actor, request_attrs)
          Loggregator.emit(app.guid, "Updated app with guid #{app.guid} (#{App.audit_hash(request_attrs)})")

          Event.create(
            space: app.space,
            type: "audit.app.update",
            actee: app.guid,
            actee_type: "app",
            actor: actor.guid,
            actor_type: "user",
            timestamp: Time.now,
            metadata: {
              request: App.audit_hash(request_attrs)
            }
          )
        end

        def record_app_create(app, actor, request_attrs)
          Loggregator.emit(app.guid, "Created app with guid #{app.guid}")

          opts = {
            type: "audit.app.create",
            actee: app.nil? ? "0" : app.guid,
            actee_type: "app",
            actor: actor.guid,
            actor_type: "user",
            timestamp: Time.now,
            metadata: {
              request: App.audit_hash(request_attrs)
            }
          }
          opts[:space] = app.space unless app.nil?

          Event.create(opts)
        end

        def record_app_delete_request(deleting_app, actor, recursive)
          Loggregator.emit(deleting_app.guid, "Deleted app with guid #{deleting_app.guid}")

          Event.create(
            space: deleting_app.space,
            type: "audit.app.delete-request",
            actee: deleting_app.guid,
            actee_type: "app",
            actor: actor.guid,
            actor_type: "user",
            timestamp: Time.now,
            metadata: {
              request: { recursive: recursive }
            }
          )
        end
      end
    end
  end
end
