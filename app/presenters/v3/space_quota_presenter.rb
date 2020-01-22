require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController::Presenters::V3
  class SpaceQuotaPresenter < BasePresenter
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
        relationships: {
          organization: {
            data: { guid: space_quota.organization.guid }
          },
          spaces: {
            data: space_data
          }
        },
        links: build_links,
      }
    end

    private

    def space_quota
      @resource
    end

    def space_data
      space_quota.spaces.map do |space|
        { guid: space.guid }
      end
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

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
