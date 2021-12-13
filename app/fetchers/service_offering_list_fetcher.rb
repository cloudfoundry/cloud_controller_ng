require 'fetchers/base_service_list_fetcher'

module VCAP::CloudController
  class ServiceOfferingListFetcher < BaseServiceListFetcher
    class << self
      def fetch(message, omniscient: false, readable_spaces_query: nil, readable_orgs_query: nil, eager_loaded_associations: [])
        dataset = select_readable(
          Service.dataset.eager(eager_loaded_associations),
          message,
          omniscient: omniscient,
          readable_orgs_query: readable_orgs_query,
          readable_spaces_query: readable_spaces_query,
        )

        filter(message, dataset).select_all(:services).distinct
      end

      private

      def join_service_plans(dataset)
        join(dataset, :left, :service_plans, service_id: Sequel[:services][:id])
      end

      def filter(message, dataset)
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

        super(message, dataset, Service)
      end
    end
  end
end
