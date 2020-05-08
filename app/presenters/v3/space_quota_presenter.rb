require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController::Presenters::V3
  class SpaceQuotaPresenter < BasePresenter
    def initialize(
      resource,
      show_secrets: false,
      censored_message: VCAP::CloudController::Presenters::Censorship::REDACTED_CREDENTIAL,
      visible_space_guids:
    )
      super(resource, show_secrets: show_secrets, censored_message: censored_message)
      @visible_space_guids = visible_space_guids
    end

    def to_hash
      {
        guid: space_quota.guid,
        created_at: space_quota.created_at,
        updated_at: space_quota.updated_at,
        name: space_quota.name,
        apps: {
          total_memory_in_mb: unlimited_to_nil(space_quota.memory_limit),
          per_process_memory_in_mb: unlimited_to_nil(space_quota.instance_memory_limit),
          total_instances: unlimited_to_nil(space_quota.app_instance_limit),
          per_app_tasks: unlimited_to_nil(space_quota.app_task_limit),
        },
        services: {
          paid_services_allowed: space_quota.non_basic_services_allowed,
          total_service_instances: unlimited_to_nil(space_quota.total_services),
          total_service_keys: unlimited_to_nil(space_quota.total_service_keys),
        },
        routes: {
          total_routes: unlimited_to_nil(space_quota.total_routes),
          total_reserved_ports: unlimited_to_nil(space_quota.total_reserved_route_ports),
        },
        relationships: {
          organization: {
            data: { guid: space_quota.organization.guid }
          },
          spaces: {
            data: filtered_visible_spaces
          }
        },
        links: build_links,
      }
    end

    private

    def space_quota
      @resource
    end

    def filtered_visible_spaces
      VCAP::CloudController::Space.where(space_quota_definition_id: space_quota.id, guid: @visible_space_guids).select(:guid).map do |space|
        { guid: space[:guid] }
      end
    end

    def build_links
      {
        self: { href: url_builder.build_url(path: "/v3/space_quotas/#{space_quota.guid}") },
        organization: { href: url_builder.build_url(path: "/v3/organizations/#{space_quota.organization.guid}") },
      }
    end

    def unlimited_to_nil(value)
      value == -1 ? nil : value
    end
  end
end
