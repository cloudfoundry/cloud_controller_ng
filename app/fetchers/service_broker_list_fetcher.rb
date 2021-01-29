require 'fetchers/base_list_fetcher'
require 'fetchers/label_selector_query_generator'

module VCAP::CloudController
  class ServiceBrokerListFetcher < BaseListFetcher
    class << self
      def fetch(message:, permitted_space_guids: nil, eager_loaded_associations: [])
        dataset = ServiceBroker.dataset.eager(eager_loaded_associations)

        if permitted_space_guids || message.requested?(:space_guids)
          dataset = dataset.join(:spaces, id: Sequel[:service_brokers][:space_id])
        end

        if permitted_space_guids
          dataset = dataset.where { Sequel[:spaces][:guid] =~ permitted_space_guids }
        end

        filter(message, dataset).select_all(:service_brokers)
      end

      private

      def filter(message, dataset)
        if message.requested?(:space_guids)
          dataset = dataset.where { Sequel[:spaces][:guid] =~ message.space_guids }
        end

        if message.requested?(:names)
          dataset = dataset.where { Sequel[:service_brokers][:name] =~ message.names }
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: ServiceBrokerLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: ServiceBroker,
          )
        end

        super(message, dataset, ServiceBroker)
      end
    end
  end
end
