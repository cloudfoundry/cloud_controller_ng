require 'fetchers/base_service_list_fetcher'

module VCAP::CloudController
  class ServiceOfferingListFetcher < BaseServiceListFetcher
    class << self
      def fetch(message, omniscient: false, readable_orgs_query: nil, readable_spaces_query: nil, eager_loaded_associations: [])
        super(Service,
              message,
              omniscient: omniscient,
              readable_orgs_query: readable_orgs_query,
              readable_spaces_query: readable_spaces_query,
              eager_loaded_associations: eager_loaded_associations)
      end

      private

      def filter(message, dataset, klass)
        if message.requested?(:names)
          dataset = dataset.where(Sequel[:services][:label] =~ message.names)
        end

        if message.requested?(:available)
          dataset = dataset.where { Sequel[:services][:active] =~ message.available? }
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: ServiceOfferingLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: Service,
          )
        end

        super(message, dataset, klass)
      end

      def join_service_plans(dataset)
        join(dataset, :inner, :service_plans, service_id: Sequel[:services][:id])
      end
    end
  end
end
