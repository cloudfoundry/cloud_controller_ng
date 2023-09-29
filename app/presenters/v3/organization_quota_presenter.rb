require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController::Presenters::V3
  class OrganizationQuotaPresenter < BasePresenter
    def initialize(
      resource,
      show_secrets: false,
      censored_message: VCAP::CloudController::Presenters::Censorship::REDACTED_CREDENTIAL,
      all_orgs_visible: false,
      visible_org_guids_query: nil
    )
      super(resource, show_secrets:, censored_message:)
      @all_orgs_visible = all_orgs_visible
      @visible_org_guids_query = visible_org_guids_query
    end

    def to_hash
      {
        guid: organization_quota.guid,
        created_at: organization_quota.created_at,
        updated_at: organization_quota.updated_at,
        name: organization_quota.name,
        apps: {
          total_memory_in_mb: convert_unlimited_to_nil(organization_quota.memory_limit),
          per_process_memory_in_mb: convert_unlimited_to_nil(organization_quota.instance_memory_limit),
          total_instances: convert_unlimited_to_nil(organization_quota.app_instance_limit),
          per_app_tasks: convert_unlimited_to_nil(organization_quota.app_task_limit),
          log_rate_limit_in_bytes_per_second: convert_unlimited_to_nil(organization_quota.log_rate_limit)
        },
        services: {
          paid_services_allowed: organization_quota.non_basic_services_allowed,
          total_service_instances: convert_unlimited_to_nil(organization_quota.total_services),
          total_service_keys: convert_unlimited_to_nil(organization_quota.total_service_keys)
        },
        routes: {
          total_routes: convert_unlimited_to_nil(organization_quota.total_routes),
          total_reserved_ports: convert_unlimited_to_nil(organization_quota.total_reserved_route_ports)
        },
        domains: {
          total_domains: convert_unlimited_to_nil(organization_quota.total_private_domains)
        },
        relationships: {
          organizations: {
            data: filtered_visible_orgs
          }
        },
        links: build_links
      }
    end

    private

    def filtered_visible_orgs
      ds = organization_quota.organizations_dataset
      ds = ds.where(guid: @visible_org_guids_query) unless @all_orgs_visible
      ds.select_map(:guid).map { |g| { guid: g } }
    end

    def organization_quota
      @resource
    end

    def convert_unlimited_to_nil(value)
      value == -1 ? nil : value
    end

    def build_links
      {
        self: { href: url_builder.build_url(path: "/v3/organization_quotas/#{organization_quota.guid}") }
      }
    end
  end
end
