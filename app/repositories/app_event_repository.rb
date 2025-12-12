require 'repositories/mixins/app_manifest_event_mixins'
require 'repositories/mixins/truncation_mixin'
require 'repositories/event_types'

module VCAP::CloudController
  module Repositories
    class AppEventRepository
      include AppManifestEventMixins
      include TruncationMixin

      CENSORED_FIELDS   = %i[encrypted_environment_json
                             command
                             environment_json
                             environment_variables
                             docker_credentials].freeze
      SYSTEM_ACTOR_HASH = { guid: 'system', type: 'system', name: 'system', user_name: 'system' }.freeze

      def create_app_crash_event(app, droplet_exited_payload)
        VCAP::AppLogEmitter.emit(app.guid, "App instance exited with guid #{app.guid} payload: #{droplet_exited_payload}")

        actor    = { name: app.name, guid: app.guid, type: 'app' }
        metadata = droplet_exited_payload.slice('instance', 'index', 'cell_id', 'exit_status', 'exit_description', 'reason')
        metadata['exit_description'] = truncate(metadata['exit_description'])

        create_app_audit_event(EventTypes::APP_CRASH, app, app.space, actor, metadata)
      end

      def record_app_update(app, space, user_audit_info, request_attrs, manifest_triggered: false)
        audit_hash = app_audit_hash(request_attrs)
        VCAP::AppLogEmitter.emit(app.guid, "Updated app with guid #{app.guid} (#{audit_hash})")

        actor    = { name: user_audit_info.user_email, guid: user_audit_info.user_guid, user_name: user_audit_info.user_name, type: 'user' }
        metadata = add_manifest_triggered(manifest_triggered, {
                                            request: audit_hash
                                          })
        create_app_audit_event(EventTypes::APP_UPDATE, app, space, actor, metadata)
      end

      def record_app_map_droplet(app, space, user_audit_info, request_attrs)
        audit_hash = app_audit_hash(request_attrs)
        VCAP::AppLogEmitter.emit(app.guid, "Updated app with guid #{app.guid} (#{audit_hash})")

        actor    = { name: user_audit_info.user_email, guid: user_audit_info.user_guid, user_name: user_audit_info.user_name, type: 'user' }
        metadata = { request: audit_hash }
        create_app_audit_event(EventTypes::APP_DROPLET_MAPPED, app, space, actor, metadata)
      end

      def record_app_apply_manifest(app, space, user_audit_info, manifest_request_yaml)
        VCAP::AppLogEmitter.emit(app.guid, "Applied manifest to app with guid #{app.guid} (#{manifest_request_yaml})")

        actor    = { name: user_audit_info.user_email, guid: user_audit_info.user_guid, user_name: user_audit_info.user_name, type: 'user' }
        metadata = { request: { manifest: manifest_request_yaml } }
        create_app_audit_event(EventTypes::APP_APPLY_MANIFEST, app, space, actor, metadata)
      end

      def record_app_create(app, space, user_audit_info, request_attrs)
        VCAP::AppLogEmitter.emit(app.guid, "Created app with guid #{app.guid}")

        actor    = { name: user_audit_info.user_email, guid: user_audit_info.user_guid, user_name: user_audit_info.user_name, type: 'user' }
        metadata = { request: app_audit_hash(request_attrs) }
        create_app_audit_event(EventTypes::APP_CREATE, app, space, actor, metadata)
      end

      def record_app_start(app, user_audit_info)
        VCAP::AppLogEmitter.emit(app.guid, "Starting app with guid #{app.guid}")

        actor = { name: user_audit_info.user_email, guid: user_audit_info.user_guid, user_name: user_audit_info.user_name, type: 'user' }
        create_app_audit_event(EventTypes::APP_START, app, app.space, actor, nil)
      end

      def record_app_restart(app, user_audit_info)
        VCAP::AppLogEmitter.emit(app.guid, "Restarted app with guid #{app.guid}")

        actor = { name: user_audit_info.user_email, guid: user_audit_info.user_guid, type: 'user', user_name: user_audit_info.user_name }
        create_app_audit_event(EventTypes::APP_RESTART, app, app.space, actor, nil)
      end

      def record_app_stop(app, user_audit_info)
        VCAP::AppLogEmitter.emit(app.guid, "Stopping app with guid #{app.guid}")

        actor = { name: user_audit_info.user_email, guid: user_audit_info.user_guid, user_name: user_audit_info.user_name, type: 'user' }
        create_app_audit_event(EventTypes::APP_STOP, app, app.space, actor, nil)
      end

      def record_app_delete_request(app, space, user_audit_info, recursive=nil)
        VCAP::AppLogEmitter.emit(app.guid, "Deleted app with guid #{app.guid}")

        actor    = { name: user_audit_info.user_email, guid: user_audit_info.user_guid, user_name: user_audit_info.user_name, type: 'user' }
        metadata = nil
        metadata = { request: { recursive: } } unless recursive.nil?
        create_app_audit_event(EventTypes::APP_DELETE_REQUEST, app, space, actor, metadata)
      end

      def actor_or_system_hash(user_audit_info)
        return SYSTEM_ACTOR_HASH if user_audit_info.user_guid.nil?

        { guid: user_audit_info.user_guid, name: user_audit_info.user_email, user_name: user_audit_info.user_name, type: 'user' }
      end

      def record_map_route(user_audit_info, route_mapping, manifest_triggered: false)
        route = route_mapping.route
        app = route_mapping.app
        actor_hash = actor_or_system_hash(user_audit_info)
        metadata = add_manifest_triggered(manifest_triggered, {
                                            route_guid: route.guid,
                                            app_port: route_mapping.app_port,
                                            route_mapping_guid: route_mapping.guid,
                                            destination_guid: route_mapping.guid,
                                            process_type: route_mapping.process_type,
                                            weight: route_mapping.weight,
                                            protocol: route_mapping.protocol
                                          })
        metadata[:route_options] = route.options if route.options.present?
        create_app_audit_event(EventTypes::APP_MAP_ROUTE, app, app.space, actor_hash, metadata)
      end

      def record_unmap_route(user_audit_info, route_mapping, manifest_triggered: false)
        route = route_mapping.route
        app = route_mapping.app
        actor_hash = actor_or_system_hash(user_audit_info)
        metadata   = add_manifest_triggered(manifest_triggered, {
                                              route_guid: route.guid,
                                              app_port: route_mapping.app_port,
                                              route_mapping_guid: route_mapping.guid,
                                              destination_guid: route_mapping.guid,
                                              process_type: route_mapping.process_type,
                                              weight: route_mapping.weight,
                                              protocol: route_mapping.protocol
                                            })
        metadata[:route_options] = route.options if route.options.present?
        create_app_audit_event(EventTypes::APP_UNMAP_ROUTE, app, app.space, actor_hash, metadata)
      end

      def record_app_restage(app, user_audit_info)
        actor_hash = { name: user_audit_info.user_email, guid: user_audit_info.user_guid, user_name: user_audit_info.user_name, type: 'user' }
        create_app_audit_event(EventTypes::APP_RESTAGE, app, app.space, actor_hash, {})
      end

      def record_src_copy_bits(dest_app, src_app, user_audit_info)
        actor_hash = { name: user_audit_info.user_email, guid: user_audit_info.user_guid, user_name: user_audit_info.user_name, type: 'user' }
        metadata   = { destination_guid: dest_app.guid }
        create_app_audit_event(EventTypes::APP_COPY_BITS, src_app, src_app.space, actor_hash, metadata)
      end

      def record_dest_copy_bits(dest_app, src_app, user_audit_info)
        actor_hash = { name: user_audit_info.user_email, guid: user_audit_info.user_guid, user_name: user_audit_info.user_name, type: 'user' }
        metadata   = { source_guid: src_app.guid }
        create_app_audit_event(EventTypes::APP_COPY_BITS, dest_app, dest_app.space, actor_hash, metadata)
      end

      def record_app_ssh_unauthorized(app, user_audit_info, index)
        actor_hash = { name: user_audit_info.user_email, guid: user_audit_info.user_guid, user_name: user_audit_info.user_name, type: 'user' }
        create_app_audit_event(EventTypes::APP_SSH_UNAUTHORIZED, app, app.space, actor_hash, { index: })
      end

      def record_app_ssh_authorized(app, user_audit_info, index)
        actor_hash = { name: user_audit_info.user_email, guid: user_audit_info.user_guid, user_name: user_audit_info.user_name, type: 'user' }
        create_app_audit_event(EventTypes::APP_SSH_AUTHORIZED, app, app.space, actor_hash, { index: })
      end

      def record_app_show_env(app, user_audit_info)
        actor_hash = { name: user_audit_info.user_email, guid: user_audit_info.user_guid, user_name: user_audit_info.user_name, type: 'user' }
        create_app_audit_event(EventTypes::APP_ENVIRONMENT_SHOW, app, app.space, actor_hash, {})
      end

      def record_app_show_environment_variables(app, user_audit_info)
        actor_hash = { name: user_audit_info.user_email, guid: user_audit_info.user_guid, user_name: user_audit_info.user_name, type: 'user' }
        create_app_audit_event(EventTypes::APP_ENVIRONMENT_VARIABLE_SHOW, app, app.space, actor_hash, {})
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
          actor_username: actor[:user_name],
          metadata: metadata
        )
      end

      def app_audit_hash(request_attrs)
        request_attrs.dup.tap do |changes|
          CENSORED_FIELDS.map(&:to_s).each do |censored|
            changes[censored] = Presenters::Censorship::PRIVATE_DATA_HIDDEN if changes.key?(censored)
          end

          v2_buildpack = changes.key?('buildpack')
          v3_buildpack = changes.key?('lifecycle') && changes['lifecycle'].key?('data') && changes['lifecycle']['data'].key?('buildpack')

          if v2_buildpack
            buildpack_attr = changes['buildpack']
            changes['buildpack'] = CloudController::UrlSecretObfuscator.obfuscate(buildpack_attr) if buildpack_attr
          elsif v3_buildpack
            buildpack_attr = changes['lifecycle']['data']['buildpack']
            changes['lifecycle']['data']['buildpack'] = CloudController::UrlSecretObfuscator.obfuscate(buildpack_attr) if buildpack_attr
          end
        end
      end
    end
  end
end
