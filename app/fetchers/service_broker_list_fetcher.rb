module VCAP::CloudController
  class ServiceBrokerListFetcher
    def fetch_all(message:)
      dataset = ServiceBroker.dataset
      filter(message, dataset)
    end

    def fetch_global_and_space_scoped(message:, space_guids:)
      dataset = ServiceBroker.dataset.where(
        Sequel[{ space_id: nil }] |
          Sequel[{ space_id: spaces_from(space_guids).map(:id) }]
      )
      filter(message, dataset)
    end

    def fetch_none
      ServiceBroker.dataset.extension(:null_dataset).nullify
    end

    private

    def filter(message, dataset)
      if message.requested?(:space_guids)
        dataset = dataset.where(
          space: spaces_from(message.space_guids)
        )
      end

      if message.requested?(:names)
        dataset = dataset.where(
          name: message.names
        )
      end

      dataset
    end

    def spaces_from(space_guids)
      Space.where(guid: space_guids)
    end
  end
end
