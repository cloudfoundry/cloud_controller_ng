require 'repositories/mixins/app_manifest_event_mixins'
require 'repositories/event_types'

module VCAP::CloudController
  module Repositories
    class RouteEventRepository
      include AppManifestEventMixins

      def record_route_create(route, actor_audit_info, request_attrs, manifest_triggered: false)
        Event.create(
          space: route.space,
          type: EventTypes::ROUTE_CREATE,
          actee: route.guid,
          actee_type: 'route',
          actee_name: route.host,
          actor: actor_audit_info.user_guid,
          actor_type: 'user',
          actor_name: actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: add_manifest_triggered(manifest_triggered, {
                                             request: request_attrs
                                           })
        )
      end

      def record_route_update(route, actor_audit_info, request_attrs)
        Event.create(
          space: route.space,
          type: EventTypes::ROUTE_UPDATE,
          actee: route.guid,
          actee_type: 'route',
          actee_name: route.host,
          actor: actor_audit_info.user_guid,
          actor_type: 'user',
          actor_name: actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: {
            request: request_attrs
          }
        )
      end

      def record_route_share(route, actor_audit_info, target_space_guids)
        Event.create(
          space: route.space,
          type: EventTypes::ROUTE_SHARE,
          actee: route.guid,
          actee_type: 'route',
          actee_name: route.host,
          actor: actor_audit_info.user_guid,
          actor_type: 'user',
          actor_name: actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: {
            target_space_guids:
          }
        )
      end

      def record_route_unshare(route, actor_audit_info, target_space_guid)
        Event.create(
          space: route.space,
          type: EventTypes::ROUTE_UNSHARE,
          actee: route.guid,
          actee_type: 'route',
          actee_name: route.host,
          actor: actor_audit_info.user_guid,
          actor_type: 'user',
          actor_name: actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: {
            target_space_guid:
          }
        )
      end

      def record_route_transfer_owner(route, actor_audit_info, original_space, target_space_guid)
        Event.create(
          space: original_space,
          type: EventTypes::ROUTE_TRANSFER_OWNER,
          actee: route.guid,
          actee_type: 'route',
          actee_name: route.host,
          actor: actor_audit_info.user_guid,
          actor_type: 'user',
          actor_name: actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          metadata: {
            target_space_guid:
          }
        )
      end

      def record_route_delete_request(route, actor_audit_info, recursive)
        Event.create(
          type: EventTypes::ROUTE_DELETE_REQUEST,
          actee: route.guid,
          actee_type: 'route',
          actee_name: route.host,
          actor: actor_audit_info.user_guid,
          actor_type: 'user',
          actor_name: actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          space_guid: route.space.guid,
          organization_guid: route.space.organization.guid,
          metadata: {
            request: { recursive: }
          }
        )
      end

      def record_route_map(route_mapping, actor_audit_info)
        Event.create(
          type: EventTypes::APP_MAP_ROUTE,
          actee: route_mapping.app_guid,
          actee_type: 'app',
          actee_name: route_mapping.app.name,
          actor: actor_audit_info.user_guid,
          actor_type: 'user',
          actor_name: actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          space_guid: route_mapping.space.guid,
          organization_guid: route_mapping.space.organization.guid,
          metadata: {
            route_guid: route_mapping.route_guid,
            app_port: route_mapping.app_port,
            destination_guid: route_mapping.guid,
            process_type: route_mapping.process_type,
            weight: route_mapping.weight
          }
        )
      end

      def record_route_unmap(route_mapping, actor_audit_info)
        Event.create(
          type: EventTypes::APP_UNMAP_ROUTE,
          actee: route_mapping.app_guid,
          actee_type: 'app',
          actee_name: route_mapping.app.name,
          actor: actor_audit_info.user_guid,
          actor_type: 'user',
          actor_name: actor_audit_info.user_email,
          actor_username: actor_audit_info.user_name,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          space_guid: route_mapping.space.guid,
          organization_guid: route_mapping.space.organization.guid,
          metadata: {
            route_guid: route_mapping.route_guid,
            app_port: route_mapping.app_port,
            destination_guid: route_mapping.guid,
            process_type: route_mapping.process_type,
            weight: route_mapping.weight
          }
        )
      end
    end
  end
end
