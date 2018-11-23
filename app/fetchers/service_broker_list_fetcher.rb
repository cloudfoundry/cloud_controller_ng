module VCAP::CloudController
  class ServiceBrokerListFetcher
    def fetch(message, space_guids=nil)
      if space_guids
        dataset = ServiceBroker.dataset.where(space: spaces_from(space_guids))
        return filter(message, dataset)
      end

      dataset = ServiceBroker.dataset
      filter(message, dataset)
    end

    def filter(message, dataset)
      if message.requested?(:space_guids)
        dataset = dataset.where(
          space: spaces_from(message.space_guids)
        )
      end

      dataset
    end

    private

    def spaces_from(space_guids)
      space_guids.map do |space_guid|
        Space.where(guid: space_guid).first
      end
    end
  end
end
