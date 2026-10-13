require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class RouteFetcher < BaseListFetcher
    class << self
      def fetch(message, readable_space_guids_dataset: nil, readable_space_ids_dataset: nil, eager_loaded_associations: [], omniscient: false)
        dataset = Route.dataset.eager(eager_loaded_associations).
                  join(:spaces, id: Sequel[:routes][:space_id]).qualify

        unless omniscient
          dataset = dataset.where(Sequel[:routes][:guid] => accessible_route_guids_dataset(
            readable_space_ids_dataset: readable_space_ids_dataset,
            readable_space_guids_dataset: readable_space_guids_dataset
          ))
        end
        filter(message, dataset)
      end

      private

      def accessible_route_guids_dataset(readable_space_ids_dataset:, readable_space_guids_dataset:)
        raise ArgumentError.new('readable space ids or guids dataset required') unless readable_space_ids_dataset || readable_space_guids_dataset

        owned_space_column = readable_space_ids_dataset ? :id : :guid
        owned_space_values = readable_space_ids_dataset || readable_space_guids_dataset
        shared_space_guids = readable_space_guids_dataset || Space.where(id: readable_space_ids_dataset).select(:guid)

        route_guids_dataset(
          owned_space_column: owned_space_column,
          owned_space_values: owned_space_values,
          shared_space_guids: shared_space_guids
        )
      end

      def route_guids_for_space_guids_dataset(space_guids)
        route_guids_dataset(
          owned_space_column: :guid,
          owned_space_values: space_guids,
          shared_space_guids: space_guids
        )
      end

      def route_guids_dataset(owned_space_column:, owned_space_values:, shared_space_guids:)
        owned_route_guids = Route.dataset.
                            join(:spaces, id: Sequel[:routes][:space_id]).
                            where(Sequel[:spaces][owned_space_column] =~ owned_space_values).
                            select(Sequel[:routes][:guid])

        shared_route_guids = Route.dataset.
                             join(:route_shares, route_guid: Sequel[:routes][:guid]).
                             where(Sequel[:route_shares][:target_space_guid] =~ shared_space_guids).
                             select(Sequel[:routes][:guid])

        owned_route_guids.union(shared_route_guids, all: true, from_self: false)
      end

      def filter(message, dataset)
        dataset = dataset.where(host: message.hosts) if message.requested?(:hosts)

        dataset = dataset.where(path: message.paths) if message.requested?(:paths)

        dataset = dataset.where(port: message.ports) if message.requested?(:ports)

        if message.requested?(:organization_guids)
          space_ids_from_orgs = Space.join(:organizations, id: :organization_id).
                                where(organizations__guid: message.organization_guids).
                                select(:spaces__id)
          dataset = dataset.where(space_id: space_ids_from_orgs)
        end

        dataset = dataset.where(domain_id: Domain.where(guid: message.domain_guids).select(:id)) if message.requested?(:domain_guids)

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
            resource_klass: Route
          )
        end

        dataset = dataset.where(Sequel[:routes][:guid] => route_guids_for_space_guids_dataset(message.space_guids)) if message.requested?(:space_guids)

        super(message, dataset, Route)
      end
    end
  end
end
