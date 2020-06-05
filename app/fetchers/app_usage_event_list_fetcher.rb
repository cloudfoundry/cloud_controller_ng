module VCAP::CloudController
  class AppUsageEventListFetcher
    class << self
      def fetch_all(message, dataset)
        if message.requested?(:guids)
          dataset = dataset.where(guid: message.guids)
        end

        dataset
      end
    end
  end
end
