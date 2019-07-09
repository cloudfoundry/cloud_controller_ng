module VCAP::CloudController
  class RouteFetcher
    class << self
      def fetch(message, readable_route_guids)
        filter(message, Route.where(guid: readable_route_guids))
      end

      private

      def filter(message, dataset)
        if message.app_guid
          destinations_route_guids = RouteMappingModel.where(app_guid: message.app_guid).select(:route_guid)
          dataset = dataset.where(guid: destinations_route_guids)
        end

        if message.requested?(:hosts)
          dataset = dataset.where(host: message.hosts)
        end

        if message.requested?(:paths)
          dataset = dataset.where(path: message.paths)
        end

        if message.requested?(:organization_guids)
          dataset = dataset.where(organization: Organization.where(guid: message.organization_guids))
        end

        if message.requested?(:space_guids)
          dataset = dataset.where(space: Space.where(guid: message.space_guids))
        end

        if message.requested?(:domain_guids)
          dataset = dataset.where(domain: Domain.where(guid: message.domain_guids))
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: RouteLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: Route,
          )
        end

        dataset
      end
    end
  end
end
