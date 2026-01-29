require 'fetchers/base_service_list_fetcher'

module VCAP::CloudController
  class ServiceOfferingListFetcher < BaseServiceListFetcher
    class << self
      def fetch(message, omniscient: false, readable_orgs_query: nil, readable_spaces_query: nil, eager_loaded_associations: [])
        super(Service,
              message,
              omniscient:,
              readable_orgs_query:,
              readable_spaces_query:,
              eager_loaded_associations:)
      end

      private

      def filter(message, dataset, klass)
        dataset = dataset.where(Sequel[:services][:unique_id] =~ message.broker_catalog_ids) if message.requested?(:broker_catalog_ids)

        dataset = dataset.where(Sequel[:services][:label] =~ message.names) if message.requested?(:names)

        dataset = dataset.where { Sequel[:services][:active] =~ message.available? } if message.requested?(:available)

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: ServiceOfferingLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: Service
          )
        end

        super
      end

      def join_service_plans(dataset)
        dataset = join(dataset, :inner, :service_plans, service_id: Sequel[:services][:id])
        distinct(dataset) # services can have multiple plans
      end

      def join_services(dataset)
        dataset # The ServiceOfferingListFetcher operates on the :services table, so there is no need for an additional JOIN.
      end

      def distinct_union(dataset)
        # The UNIONed :services datasets (permissions granted on org level for plans / permissions
        # granted on space level for brokers / public plans) might contain duplicate entries.
        distinct(dataset)
      end
    end
  end
end
