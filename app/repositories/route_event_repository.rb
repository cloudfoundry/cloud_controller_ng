require 'repositories/mixins/app_manifest_event_mixins'

module VCAP::CloudController
  module Repositories
    class RouteEventRepository
      include AppManifestEventMixins

      def record_route_create(route, actor_audit_info, request_attrs, manifest_triggered: false)
        Event.create(
          space:          route.space,
          type:           'audit.route.create',
          actee:          route.guid,
          actee_type:     'route',
          actee_name:     route.host,
          actor:          actor_audit_info.user_guid,
          actor_type:     'user',
          actor_name:     actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp:      Sequel::CURRENT_TIMESTAMP,
          metadata:       add_manifest_triggered(manifest_triggered, {
            request: request_attrs,
          })
        )
      end

      def record_route_update(route, actor_audit_info, request_attrs)
        Event.create(
          space:          route.space,
          type:           'audit.route.update',
          actee:          route.guid,
          actee_type:     'route',
          actee_name:     route.host,
          actor:          actor_audit_info.user_guid,
          actor_type:     'user',
          actor_name:     actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp:      Sequel::CURRENT_TIMESTAMP,
          metadata:       {
            request: request_attrs
          }
        )
      end

      def record_route_share(route, actor_audit_info, target_space_guids)
        Event.create(
          space:          route.space,
          type:           'audit.route.share',
          actee:          route.guid,
          actee_type:     'route',
          actee_name:     route.host,
          actor:          actor_audit_info.user_guid,
          actor_type:     'user',
          actor_name:     actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp:      Sequel::CURRENT_TIMESTAMP,
          metadata:       {
            target_space_guids: target_space_guids
          }
        )
      end

      def record_route_unshare(route, actor_audit_info, target_space_guid)
        Event.create(
          space:          route.space,
          type:           'audit.route.unshare',
          actee:          route.guid,
          actee_type:     'route',
          actee_name:     route.host,
          actor:          actor_audit_info.user_guid,
          actor_type:     'user',
          actor_name:     actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp:      Sequel::CURRENT_TIMESTAMP,
          metadata:       {
            target_space_guid: target_space_guid
          }
        )
      end

      def record_route_transfer_owner(route, actor_audit_info, original_space, target_space_guid)
        Event.create(
          space:          original_space,
          type:           'audit.route.transfer-owner',
          actee:          route.guid,
          actee_type:     'route',
          actee_name:     route.host,
          actor:          actor_audit_info.user_guid,
          actor_type:     'user',
          actor_name:     actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp:      Sequel::CURRENT_TIMESTAMP,
          metadata:       {
            target_space_guid: target_space_guid
          }
        )
      end

      def record_route_delete_request(route, actor_audit_info, recursive)
        Event.create(
          type:              'audit.route.delete-request',
          actee:             route.guid,
          actee_type:        'route',
          actee_name:        route.host,
          actor:             actor_audit_info.user_guid,
          actor_type:        'user',
          actor_name:        actor_audit_info.user_email,
          actor_username:    actor_audit_info.user_name,
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          space_guid:        route.space.guid,
          organization_guid: route.space.organization.guid,
          metadata:          {
            request: { recursive: recursive }
          }
        )
      end

      def record_route_map(route_mapping, actor_audit_info)
        Event.create(
          type:              'audit.app.map-route',
          actee:             route_mapping.app.guid,
          actee_type:        'app',
          actee_name:        route_mapping.app.name,
          actor:             actor_audit_info.user_guid,
          actor_type:        'user',
          actor_name:        actor_audit_info.user_email,
          actor_username:    actor_audit_info.user_name,
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          space_guid:        route_mapping.space.guid,
          organization_guid: route_mapping.space.organization.guid,
          metadata:          {
            route_guid:       route_mapping.route.guid,
            app_port:         route_mapping.app_port,
            destination_guid: route_mapping.guid,
            process_type:     route_mapping.process_type,
            weight:           route_mapping.weight,
          }
        )
      end

      def record_route_unmap(route_mapping, actor_audit_info)
        Event.create(
          type:              'audit.app.unmap-route',
          actee:             route_mapping.app.guid,
          actee_type:        'app',
          actee_name:        route_mapping.app.name,
          actor:             actor_audit_info.user_guid,
          actor_type:        'user',
          actor_name:        actor_audit_info.user_email,
          actor_username:    actor_audit_info.user_name,
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          space_guid:        route_mapping.space.guid,
          organization_guid: route_mapping.space.organization.guid,
          metadata:          {
            route_guid:       route_mapping.route.guid,
            app_port:         route_mapping.app_port,
            destination_guid: route_mapping.guid,
            process_type:     route_mapping.process_type,
            weight: route_mapping.weight
          }
        )
      end
    end
  end
end
