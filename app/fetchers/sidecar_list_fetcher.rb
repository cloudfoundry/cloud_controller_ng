require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class SidecarListFetcher < BaseListFetcher
    class << self
      def fetch_for_app(message, app_guid)
        app, _ = AppFetcher.new.fetch(app_guid)
        [app, filter(message, app&.sidecars_dataset)]
      end

      def fetch_for_process(message, process_guid)
        process, _ = ProcessFetcher.fetch(process_guid: process_guid)
        [process, filter(message, process&.sidecars_dataset)]
      end

      private

      def filter(message, dataset)
        super(message, dataset, SidecarModel)
      end
    end
  end
end
