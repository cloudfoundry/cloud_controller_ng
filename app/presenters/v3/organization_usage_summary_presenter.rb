require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class OrganizationUsageSummaryPresenter < BasePresenter
    def to_hash
      {
        usage_summary: {
          started_instances: VCAP::CloudController::OrganizationInstanceUsageCalculator.get_instance_usage(org),
          memory_in_mb: org.memory_used,
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
