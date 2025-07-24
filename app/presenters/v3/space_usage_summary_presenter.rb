require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class SpaceUsageSummaryPresenter < BasePresenter
    def to_hash
      {
        usage_summary: {
          started_instances: started_instances,
          memory_in_mb: space.memory_used,
          routes: space.routes_dataset.count,
          service_instances: space.service_instances_dataset.count,
          reserved_ports: VCAP::CloudController::SpaceReservedRoutePorts.new(space).count,
          domains: space.organization.owned_private_domains_dataset.count,
          per_app_tasks: space.running_and_pending_tasks_count,
          service_keys: space.number_service_keys
        },
        links: build_links
      }
    end

    private

    def space
      @resource
    end

    def started_instances
      space.processes_dataset.where(state: VCAP::CloudController::ProcessModel::STARTED).sum(:instances) || 0
    end

    def build_links
      {
        self: {
          href: url_builder.build_url(path: "/v3/spaces/#{space.guid}/usage_summary")
        },
        space: {
          href: url_builder.build_url(path: "/v3/spaces/#{space.guid}")
        }
      }
    end
  end
end
