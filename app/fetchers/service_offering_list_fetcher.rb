require 'fetchers/base_service_list_fetcher'

module VCAP::CloudController
  class ServiceOfferingListFetcher < BaseServiceListFetcher
    class << self
      def fetch(message, omniscient: false, readable_orgs_query: nil, readable_spaces_query: nil, eager_loaded_associations: [])
        dataset = super(Service,
                        message,
                        omniscient:,
                        readable_orgs_query:,
                        readable_spaces_query:,
                        eager_loaded_associations:)
        # for service offerings there might be an overlap between the UNIONed subqueries (i.e. one plan is public and another one is org restricted)
        dataset.distinct
      end

      private

      def filter(message, dataset, klass)
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

        super(message, dataset, klass)
      end

      def join_service_plans(dataset)
        dataset = join(dataset, :inner, :service_plans, service_id: Sequel[:services][:id])
        dataset.distinct # services can have multiple plans
      end
    end
  end
end
