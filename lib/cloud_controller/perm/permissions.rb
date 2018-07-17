module VCAP
  module CloudController
    module Perm
      class Permissions
        ORG_AUDITOR_ACTION = 'org.auditor'.freeze
        ORG_BILLING_MANAGER_ACTION = 'org.billing_manager'.freeze
        ORG_MANAGER_ACTION = 'org.manager'.freeze
        ORG_USER_ACTION = 'org.user'.freeze

        SPACE_AUDITOR_ACTION = 'space.auditor'.freeze
        SPACE_DEVELOPER_ACTION = 'space.developer'.freeze
        SPACE_MANAGER_ACTION = 'space.manager'.freeze

        def initialize(perm_client:, user_id:, issuer:, roles:)
          @perm_client = perm_client
          @user_id = user_id
          @roles = roles
          @issuer = issuer
        end

        # Taken from lib/cloud_controller/permissions.rb
        def can_read_globally?
          roles.admin? || roles.admin_read_only? || roles.global_auditor?
        end

        # Taken from lib/cloud_controller/permissions.rb
        def can_read_secrets_globally?
          roles.admin? || roles.admin_read_only?
        end

        # Taken from lib/cloud_controller/permissions.rb
        def can_write_globally?
          roles.admin?
        end

        def readable_org_guids
          if can_read_globally?
            VCAP::CloudController::Organization.select(:guid).all.map(&:guid)
          else
            perm_client.list_unique_resource_patterns(
              user_id: user_id,
              issuer: issuer,
              actions: [
                ORG_MANAGER_ACTION,
                ORG_BILLING_MANAGER_ACTION,
                ORG_AUDITOR_ACTION,
                ORG_USER_ACTION
              ]
            )
          end
        end

        def can_read_from_org?(org_id)
          can_read_globally? ||
          has_any_permission?([
            { action: ORG_MANAGER_ACTION, resource: org_id },
            { action: ORG_AUDITOR_ACTION, resource: org_id },
            { action: ORG_USER_ACTION, resource: org_id },
            { action: ORG_BILLING_MANAGER_ACTION, resource: org_id },
          ])
        end

        def can_write_to_org?(org_id)
          can_write_globally? || has_any_permission?([
            { action: ORG_MANAGER_ACTION, resource: org_id },
          ])
        end

        def readable_space_guids
          if can_read_globally?
            VCAP::CloudController::Space.select(:guid).all.map(&:guid)
          else
            space_guids_for_actions(
              [
                SPACE_DEVELOPER_ACTION,
                SPACE_MANAGER_ACTION,
                SPACE_AUDITOR_ACTION,
              ],
              [
                ORG_MANAGER_ACTION,
              ])
          end
        end

        def can_read_from_space?(space_id, org_id)
          can_read_globally? || has_any_permission?([
            { action: SPACE_DEVELOPER_ACTION, resource: space_id },
            { action: SPACE_MANAGER_ACTION, resource: space_id },
            { action: SPACE_AUDITOR_ACTION, resource: space_id },
            { action: ORG_MANAGER_ACTION, resource: org_id },
          ])
        end

        def can_read_secrets_in_space?(space_id, org_id)
          can_read_secrets_globally? || has_any_permission?([
            { action: SPACE_DEVELOPER_ACTION, resource: space_id },
          ])
        end

        def can_write_to_space?(space_id)
          can_write_globally? || has_any_permission?([
            { action: SPACE_DEVELOPER_ACTION, resource: space_id },
          ])
        end

        def can_update_space?(space_id)
          can_write_globally? || has_any_permission?([
            { action: SPACE_MANAGER_ACTION, resource: space_id },
          ])
        end

        def can_read_from_isolation_segment?(isolation_segment)
          can_read_globally? ||
            isolation_segment.spaces.any? { |space| can_read_from_space?(space.guid, space.organization.guid) } ||
            isolation_segment.organizations.any? { |org| can_read_from_org?(org.guid) }
        end

        def readable_route_guids
          if can_read_globally?
            VCAP::CloudController::Route.select(:guid).all.map(&:guid)
          else
            route_space_guids = space_guids_for_actions(
              [
                SPACE_DEVELOPER_ACTION,
                SPACE_MANAGER_ACTION,
                SPACE_AUDITOR_ACTION,
              ],
              [
                ORG_MANAGER_ACTION,
                ORG_AUDITOR_ACTION,
              ])

            Space.where("#{Space.table_name}__guid".to_sym => route_space_guids).
              join(Route.table_name.to_sym, space_id: :id).
              select("#{Route.table_name}__guid".to_sym).
              all.map(&:guid)
          end
        end

        def can_read_route?(space_id, org_id)
          can_read_globally? || has_any_permission?([
            { action: SPACE_DEVELOPER_ACTION, resource: space_id },
            { action: SPACE_MANAGER_ACTION, resource: space_id },
            { action: SPACE_AUDITOR_ACTION, resource: space_id },
            { action: ORG_MANAGER_ACTION, resource: org_id },
            { action: ORG_AUDITOR_ACTION, resource: org_id },
          ])
        end

        def readable_app_guids
          if can_read_globally?
            VCAP::CloudController::AppModel.select(:guid).all.map(&:guid)
          else
            app_space_guids = space_guids_for_actions(
              [
                SPACE_DEVELOPER_ACTION,
                SPACE_MANAGER_ACTION,
                SPACE_AUDITOR_ACTION,
              ],
              [
                ORG_MANAGER_ACTION,
              ])

            Space.where("#{Space.table_name}__guid".to_sym => app_space_guids).
              join(AppModel.table_name.to_sym, space_guid: :guid).
              select("#{AppModel.table_name}__guid".to_sym).
              all.map(&:guid)
          end
        end

        def readable_route_mapping_guids
          if can_read_globally?
            VCAP::CloudController::RouteMappingModel.select(:guid).all.map(&:guid)
          else
            route_mapping_space_guids = space_guids_for_actions(
              [
                SPACE_DEVELOPER_ACTION,
                SPACE_MANAGER_ACTION,
                SPACE_AUDITOR_ACTION,
              ],
              [
                ORG_MANAGER_ACTION,
              ])

            Space.where("#{Space.table_name}__guid".to_sym => route_mapping_space_guids).
              join(AppModel.table_name.to_sym, space_guid: :guid).
              join(RouteMappingModel.table_name.to_sym, app_guid: :guid).
              select("#{RouteMappingModel.table_name}__guid".to_sym).
              all.map(&:guid)
          end
        end

        private

        attr_reader :perm_client, :user_id, :roles, :issuer

        def has_any_permission?(permissions)
          perm_client.has_any_permission?(permissions: permissions, user_id: user_id, issuer: issuer)
        end

        def space_guids_for_actions(space_actions, org_actions)
          space_guids = perm_client.list_unique_resource_patterns(
            user_id: user_id,
            issuer: issuer,
            actions: space_actions
          )
          org_guids = perm_client.list_unique_resource_patterns(
            user_id: user_id,
            issuer: issuer,
            actions: org_actions
          )

          all_guids = space_guids +
            Organization.where("#{Organization.table_name}__guid".to_sym => org_guids).
                      join(Space.table_name.to_sym, organization_id: :id).
                      select("#{Space.table_name}__guid".to_sym).all.map(&:guid)

          all_guids.uniq
        end
      end
    end
  end
end
