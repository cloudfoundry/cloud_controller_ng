module VCAP::CloudController
  class RouteFetcher
    class << self
      def fetch(message, readable_route_guids)
        filter(message, Route.where(guid: readable_route_guids))
      end

      private

      def filter(message, dataset)
        if message.requested?(:hosts)
          dataset = dataset.where(host: message.hosts)
        end

        if message.requested?(:paths)
          dataset = dataset.where(path: message.paths)
        end

        if message.requested?(:organization_guids)
          dataset = dataset.where(organization: Organization.where(guid: message.organization_guids))
        end

        if message.requested?(:domain_guids)
          dataset = dataset.where(domain: Domain.where(guid: message.domain_guids))
        end

        dataset
      end
    end
  end
end
