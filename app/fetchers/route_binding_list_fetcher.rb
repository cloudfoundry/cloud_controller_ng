require 'fetchers/base_list_fetcher'

module VCAP
  module CloudController
    class RouteBindingListFetcher < BaseListFetcher
      class << self
        def fetch_all(message, eager_loaded_associations: [])
          filter(message, all_bindings(eager_loaded_associations)).
            select_all(:route_bindings)
        end

        def fetch_some(message, space_guids:, eager_loaded_associations: [])
          bindings = all_bindings(eager_loaded_associations).
                     join(:spaces, id: Sequel[:service_instances][:space_id]).
                     where { Sequel[:spaces][:guid] =~ space_guids }

          filter(message, bindings).
            select_all(:route_bindings)
        end

        private

        def filter(message, bindings)
          filters = {
            service_instance_guids: ->(dataset, requested) do
              dataset.where { Sequel[:service_instances][:guid] =~ requested.service_instance_guids }
            end,
            service_instance_names: ->(dataset, requested) do
              dataset.where { Sequel[:service_instances][:name] =~ requested.service_instance_names }
            end,
            route_guids: ->(dataset, requested) do
              dataset.where { Sequel[:routes][:guid] =~ requested.route_guids }
            end,
            label_selector: ->(dataset, requested) do
              LabelSelectorQueryGenerator.add_selector_queries(
                label_klass: RouteBindingLabelModel,
                resource_dataset: dataset,
                requirements: requested.requirements,
                resource_klass: RouteBinding
              )
            end
          }

          bindings = filters.
                     select { |filter_name| message.requested?(filter_name) }.
                     values.
                     reduce(bindings) { |dataset, filter| filter.call(dataset, message) }

          super(message, bindings, RouteBinding)
        end

        def all_bindings(eager_loaded_associations)
          RouteBinding.dataset.eager(eager_loaded_associations).
            join(:service_instances, id: Sequel[:route_bindings][:service_instance_id]).
            join(:routes, id: Sequel[:route_bindings][:route_id])
        end
      end
    end
  end
end
