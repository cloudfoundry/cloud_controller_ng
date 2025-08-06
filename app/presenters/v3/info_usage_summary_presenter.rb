require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/helpers/censorship'

module VCAP::CloudController::Presenters::V3
  class InfoUsageSummaryPresenter < BasePresenter
    def to_hash
      {
        usage_summary: {
          started_instances: usage_summary.started_instances,
          memory_in_mb: usage_summary.memory_in_mb,
          routes: usage_summary.routes,
          service_instances: usage_summary.service_instances,
          reserved_ports: usage_summary.reserved_ports,
          domains: usage_summary.domains,
          per_app_tasks: usage_summary.per_app_tasks,
          service_keys: usage_summary.service_keys
        },
        links: {
          self: { href: build_self }
        }
      }
    end

    private

    def usage_summary
      @resource
    end

    def build_self
      url_builder.build_url(path: '/v3/info/usage_summary')
    end
  end
end
