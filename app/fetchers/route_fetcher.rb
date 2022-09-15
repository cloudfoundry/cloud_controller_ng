require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class RouteFetcher < BaseListFetcher
    class << self
      def fetch(message, readable_space_guids_dataset: nil, eager_loaded_associations: [], omniscient: false)
        dataset = Route.dataset.eager(eager_loaded_associations).
                  join(:spaces, id: Sequel[:routes][:space_id]).
                  left_join(:route_shares, route_guid: Sequel[:routes][:guid]).qualify

        unless omniscient
          dataset = dataset.where do
            (Sequel[:spaces][:guid] =~ readable_space_guids_dataset) |
              (Sequel[:route_shares][:target_space_guid] =~ readable_space_guids_dataset)
          end
        end
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

        if message.requested?(:domain_guids)
          dataset = dataset.where(domain_id: Domain.where(guid: message.domain_guids).select(:id))
        end

        if message.requested?(:app_guids)
          destinations_route_guids = RouteMappingModel.where(app_guid: message.app_guids).select(:route_guid)
          dataset = dataset.where(Sequel[:routes][:guid] =~ destinations_route_guids)
        end

        if message.requested?(:service_instance_guids)
          service_instance_route_guids = RouteBinding.
                                         join(:routes, id: :route_id).
                                         join(:service_instances, id: :route_bindings__service_instance_id).
                                         where { { Sequel[:service_instances][:guid] => message.service_instance_guids } }.
                                         select(:routes__guid)
          dataset = dataset.where(Sequel[:routes][:guid] =~ service_instance_route_guids)
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: RouteLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: Route,
          )
        end

        if message.requested?(:space_guids)
          dataset = dataset.where do
            (Sequel[:spaces][:guid] =~ message.space_guids) |
              (Sequel[:route_shares][:target_space_guid] =~ message.space_guids)
          end
        end

        super(message, dataset, Route)
      end
    end
  end
end
