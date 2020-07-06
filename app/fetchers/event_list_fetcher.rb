require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/label_selector_query_generator'
require 'fetchers/base_fetcher'

module VCAP::CloudController
  class EventListFetcher < BaseFetcher
    # this is important. We need the fetcher to be a static class
    class << self
      def fetch_all(message, event_dataset)
        filter(message, event_dataset)
      end

      private

      def filter(message, dataset)
        dataset = super(message, dataset)

        if message.requested?(:types)
          dataset = dataset.where(type: message.types)
        end

        if message.requested?(:target_guids)
          dataset = dataset.where(actee: message.target_guids)
        end

        if message.requested?(:space_guids)
          dataset = dataset.where(space_guid: message.space_guids)
        end

        if message.requested?(:organization_guids)
          dataset = dataset.where(organization_guid: message.organization_guids)
        end
        dataset
      end
    end
  end
end
