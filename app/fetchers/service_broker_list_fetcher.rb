module VCAP::CloudController
  class ServiceBrokerListFetcher
    def fetch(message:, permitted_space_guids: nil)
      if permitted_space_guids
        dataset = ServiceBroker.dataset.where(Sequel[:service_brokers][:space_id] => spaces_from(permitted_space_guids))
        return filter(message, dataset)
      end

      dataset = ServiceBroker.dataset
      filter(message, dataset)
    end

    private

    def filter(message, dataset)
      if message.requested?(:space_guids)
        dataset = dataset.where(
          Sequel[:service_brokers][:space_id] => spaces_from(message.space_guids)
        )
      end

      if message.requested?(:names)
        dataset = dataset.where(
          name: message.names
        )
      end

      if message.requested?(:label_selector)
        dataset = LabelSelectorQueryGenerator.add_selector_queries(
          label_klass: ServiceBrokerLabelModel,
          resource_dataset: dataset,
          requirements: message.requirements,
          resource_klass: ServiceBroker,
        )
      end

      dataset
    end

    def spaces_from(space_guids)
      Space.where(guid: space_guids).select(:id)
    end
  end
end
