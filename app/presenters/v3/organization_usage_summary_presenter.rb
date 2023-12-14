require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class OrganizationUsageSummaryPresenter < BasePresenter
    def to_hash
      org_usage = VCAP::CloudController::OrganizationQuotaUsage.new(org)
      {
        usage_summary: {
          started_instances: VCAP::CloudController::OrganizationInstanceUsageCalculator.get_instance_usage(org),
          memory_in_mb: org.memory_used,
          routes: org_usage.routes,
          service_instances: org_usage.service_instances,
          reserved_ports: org_usage.reserved_route_ports,
          domains: org_usage.private_domains,
          per_app_tasks: org_usage.app_tasks,
          service_keys: org_usage.service_keys
        },
        links: build_links
      }
    end

    private

    def org
      @resource
    end

    def build_links
      {
        self: {
          href: url_builder.build_url(path: "/v3/organizations/#{org.guid}/usage_summary")
        },
        organization: {
          href: url_builder.build_url(path: "/v3/organizations/#{org.guid}")
        }
      }
    end
  end
end
