module VCAP::CloudController
  module Repositories
    module Runtime
      class AppEventRepository
        SYSTEM_ACTOR_HASH = { guid: "system", type: "system", name: "system" }

        def create_app_exit_event(app, droplet_exited_payload)
          Loggregator.emit(app.guid, "App instance exited with guid #{app.guid} payload: #{droplet_exited_payload}")

          actor = { name: app.name, guid: app.guid, type: "app" }
          metadata = droplet_exited_payload.slice("instance", "index", "exit_status", "exit_description", "reason")
          create_app_audit_event("app.crash", app, actor, metadata)
        end

        def record_app_update(app, actor, actor_name, request_attrs)
          Loggregator.emit(app.guid, "Updated app with guid #{app.guid} (#{App.audit_hash(request_attrs)})")

          actor = { name: actor_name, guid: actor.guid, type: "user" }
          metadata = { request: App.audit_hash(request_attrs) }
          create_app_audit_event("audit.app.update", app, actor, metadata)
        end

        def record_app_create(app, actor, actor_name, request_attrs)
          Loggregator.emit(app.guid, "Created app with guid #{app.guid}")

          actor = { name: actor_name, guid: actor.guid, type: "user" }
          metadata = { request: App.audit_hash(request_attrs) }
          create_app_audit_event("audit.app.create", app, actor, metadata)
        end

        def record_app_delete_request(deleting_app, actor, actor_name, recursive)
          Loggregator.emit(deleting_app.guid, "Deleted app with guid #{deleting_app.guid}")

          actor = { name: actor_name, guid: actor.guid, type: "user" }
          metadata = { request: { recursive: recursive } }
          create_app_audit_event("audit.app.delete-request", deleting_app, actor, metadata)
        end

        def record_map_route(app, route, actor, actor_name)
          actor_hash = actor.nil? ? SYSTEM_ACTOR_HASH : { guid: actor.guid, name: actor_name, type: "user" }
          metadata = { route_guid: route.guid }
          create_app_audit_event("audit.app.map-route", app, actor_hash, metadata)
        end

        def record_unmap_route(app, route, actor, actor_name)
          actor_hash = actor.nil? ? SYSTEM_ACTOR_HASH : { guid: actor.guid, name: actor_name, type: "user" }
          metadata = { route_guid: route.guid }
          create_app_audit_event("audit.app.unmap-route", app, actor_hash, metadata)
        end

        private

        def create_app_audit_event(type, app, actor, metadata)
          Event.create(
            space: app.space,
            type: type,
            timestamp: Time.now,
            actee: app.guid,
            actee_type: "app",
            actee_name: app.name,
            actor: actor[:guid],
            actor_type: actor[:type],
            actor_name: actor[:name],
            metadata: metadata
          )
        end
      end
    end
  end
end
