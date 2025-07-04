require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class AppUsageConsumerListFetcher < BaseListFetcher
    class << self
      def fetch_all(message, dataset)
        dataset = filter(message, dataset, AppUsageConsumer)

        dataset = dataset.where(consumer_guid: message.consumer_guids) if message.requested?(:consumer_guids)

        dataset = dataset.where(last_processed_guid: message.last_processed_guids) if message.requested?(:last_processed_guids)

        dataset
      end
    end
  end
end
