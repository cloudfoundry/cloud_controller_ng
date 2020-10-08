require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class RouteFetcher < BaseListFetcher
    class << self
      def fetch(message, readable_route_dataset, eager_loaded_associations: [])
        dataset = readable_route_dataset.eager(eager_loaded_associations).qualify
        filter(message, dataset)
      end

      private

      def filter(message, dataset)
        if message.requested?(:hosts)
          dataset = dataset.where(host: message.hosts)
        end

        if message.requested?(:paths)
          dataset = dataset.where(path: message.paths)
        end

        if message.requested?(:ports)
          dataset = dataset.where(port: message.ports)
        end

        if message.requested?(:organization_guids)
          space_ids = Organization.where(guid: message.organization_guids).map(&:spaces).flatten.map(&:id)
          dataset = dataset.where(space_id: space_ids)
        end

        if message.requested?(:space_guids)
          dataset = dataset.where(space_id: Space.where(guid: message.space_guids).select(:id))
        end

        if message.requested?(:domain_guids)
          dataset = dataset.where(domain_id: Domain.where(guid: message.domain_guids).select(:id))
        end

        if message.requested?(:app_guids)
          destinations_route_guids = RouteMappingModel.where(app_guid: message.app_guids).select(:route_guid)
          dataset = dataset.where(guid: destinations_route_guids)
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: RouteLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: Route,
          )
        end

        super(message, dataset, Route)
      end
    end
  end
end
