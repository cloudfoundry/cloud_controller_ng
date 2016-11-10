require 'pry'

module VCAP::CloudController
  module Repositories
    class UserEventRepository
      def record_space_role_add(space, assignee, role, actor, actor_name, request_attrs={})
        record_space_role_event("audit.user.space_#{role}_add", space, assignee, actor, actor_name, request_attrs)
      end

      def record_space_role_remove(space, assignee, role, actor, actor_name, request_attrs={})
        record_space_role_event("audit.user.space_#{role}_remove", space, assignee, actor, actor_name, request_attrs)
      end

      def record_organization_role_add(organization, assignee, role, actor, actor_name, request_attrs={})
        record_organization_role_event("audit.user.organization_#{role}_add", organization, assignee, actor, actor_name, request_attrs)
      end

      def record_organization_role_remove(organization, assignee, role, actor, actor_name, request_attrs={})
        record_organization_role_event("audit.user.organization_#{role}_remove", organization, assignee, actor, actor_name, request_attrs)
      end

      private

      def record_space_role_event(type, space, assignee, actor, actor_name, request_attrs)
        username = assignee.username ? assignee.username : ''
        Event.create(
          type:       type,
          space:      space,
          actee:      assignee.guid,
          actee_type: 'user',
          actee_name: username,
          actor:      actor.guid,
          actor_type: 'user',
          actor_name: actor_name,
          timestamp:  Sequel::CURRENT_TIMESTAMP,
          metadata:   {
              request: request_attrs
          }
        )
      end

      def record_organization_role_event(type, organization, assignee, actor, actor_name, request_attrs)
        username = assignee.username ? assignee.username : ''
        Event.create(
          type:       type,
          organization_guid:      organization.guid,
          actee:      assignee.guid,
          actee_type: 'user',
          actee_name: username,
          actor:      actor.guid,
          actor_type: 'user',
          actor_name: actor_name,
          timestamp:  Sequel::CURRENT_TIMESTAMP,
          metadata:   {
              request: request_attrs
          }
        )
      end
    end
  end
end
