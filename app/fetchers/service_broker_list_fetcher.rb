module VCAP::CloudController
  class ServiceBrokerListFetcher
    def fetch(message:, permitted_space_guids: nil)
      if permitted_space_guids
        dataset = ServiceBroker.dataset.where(space: spaces_from(permitted_space_guids))
        return filter(message, dataset)
      end

      dataset = ServiceBroker.dataset
      filter(message, dataset)
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
      spaces = space_guids.map do |space_guid|
        Space.where(guid: space_guid).first
      end
      spaces.compact
    end
  end
end
