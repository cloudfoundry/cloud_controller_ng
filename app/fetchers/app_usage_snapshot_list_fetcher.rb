require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class AppUsageSnapshotListFetcher < BaseListFetcher
    class << self
      def fetch_all(message, dataset)
        filter(message, dataset)
      end

      private

      def filter(message, dataset)
        super(message, dataset, AppUsageSnapshot)
      end
    end
  end
end
