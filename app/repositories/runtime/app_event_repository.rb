module VCAP::CloudController
  module Repositories
    module Runtime
      class AppEventRepository
        CENSORED_FIELDS = [:encrypted_environment_json, :command, :environment_json]
        CENSORED_MESSAGE = 'PRIVATE DATA HIDDEN'.freeze
        SYSTEM_ACTOR_HASH = { guid: 'system', type: 'system', name: 'system' }

        def create_app_exit_event(app, droplet_exited_payload)
          Loggregator.emit(app.guid, "App instance exited with guid #{app.guid} payload: #{droplet_exited_payload}")

          actor = { name: app.name, guid: app.guid, type: 'app' }
          metadata = droplet_exited_payload.slice('instance', 'index', 'exit_status', 'exit_description', 'reason')
          create_app_audit_event('app.crash', app, app.space, actor, metadata)
        end

        def record_app_update(app, space, actor, actor_name, request_attrs)
          Loggregator.emit(app.guid, "Updated app with guid #{app.guid} (#{app_audit_hash(request_attrs)})")

          actor = { name: actor_name, guid: actor.guid, type: 'user' }
          metadata = { request: app_audit_hash(request_attrs), prior_state: app.prior_state }
          create_app_audit_event('audit.app.update', app, space, actor, metadata)
        end

        def record_app_create(app, space, actor, actor_name, request_attrs)
          Loggregator.emit(app.guid, "Created app with guid #{app.guid}")

          actor = { name: actor_name, guid: actor.guid, type: 'user' }
          metadata = { request: app_audit_hash(request_attrs) }
          create_app_audit_event('audit.app.create', app, space, actor, metadata)
        end

        def record_app_delete_request(app, space, actor, actor_name, recursive)
          Loggregator.emit(app.guid, "Deleted app with guid #{app.guid}")

          actor = { name: actor_name, guid: actor.guid, type: 'user' }
          metadata = { request: { recursive: recursive } }
          create_app_audit_event('audit.app.delete-request', app, space, actor, metadata)
        end

        def record_map_route(app, route, actor, actor_name)
          actor_hash = actor.nil? ? SYSTEM_ACTOR_HASH : { guid: actor.guid, name: actor_name, type: 'user' }
          metadata = { route_guid: route.guid }
          create_app_audit_event('audit.app.map-route', app, app.space, actor_hash, metadata)
        end

        def record_unmap_route(app, route, actor, actor_name)
          actor_hash = actor.nil? ? SYSTEM_ACTOR_HASH : { guid: actor.guid, name: actor_name, type: 'user' }
          metadata = { route_guid: route.guid }
          create_app_audit_event('audit.app.unmap-route', app, app.space, actor_hash, metadata)
        end

        def record_app_restage(app, actor, actor_name)
          actor_hash = { name: actor_name, guid: actor.guid, type: 'user' }
          create_app_audit_event('audit.app.restage', app, app.space, actor_hash, {})
        end

        def record_src_copy_bits(dest_app, src_app, actor, actor_name)
          actor_hash = { name: actor_name, guid: actor.guid, type: 'user' }
          metadata = { destination_guid: dest_app.guid }
          create_app_audit_event('audit.app.copy-bits', src_app, src_app.space, actor_hash, metadata)
        end

        def record_dest_copy_bits(dest_app, src_app, actor, actor_name)
          actor_hash = { name: actor_name, guid: actor.guid, type: 'user' }
          metadata = { source_guid: src_app.guid }
          create_app_audit_event('audit.app.copy-bits', dest_app, dest_app.space, actor_hash, metadata)
        end

        private

        def create_app_audit_event(type, app, space, actor, metadata)
          Event.create(
            space: space,
            type: type,
            timestamp: Sequel::CURRENT_TIMESTAMP,
            actee: app.guid,
            actee_type: 'app',
            actee_name: app.name,
            actor: actor[:guid],
            actor_type: actor[:type],
            actor_name: actor[:name],
            metadata: metadata
          )
        end

        def app_audit_hash(request_attrs)
          request_attrs.dup.tap do |changes|
            CENSORED_FIELDS.map(&:to_s).each do |censored|
              changes[censored] = CENSORED_MESSAGE if changes.key?(censored)
            end
          end
        end
      end
    end
  end
end
