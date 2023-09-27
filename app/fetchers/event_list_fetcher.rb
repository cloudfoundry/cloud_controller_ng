require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/label_selector_query_generator'
require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class EventListFetcher < BaseListFetcher
    class << self
      def fetch_all(message, event_dataset)
        filter(message, event_dataset)
      end

      private

      def filter(message, dataset)
        dataset = dataset.where(type: message.types) if message.requested?(:types)

        if message.requested?(:target_guids)
          dataset = if message.exclude_target_guids?
                      dataset.exclude(actee: message.target_guids[:not])
                    else
                      dataset.where(actee: message.target_guids)
                    end
        end

        dataset = dataset.where(space_guid: message.space_guids) if message.requested?(:space_guids)

        dataset = dataset.where(organization_guid: message.organization_guids) if message.requested?(:organization_guids)

        super(message, dataset, Event)
      end
    end
  end
end
