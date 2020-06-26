require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/label_selector_query_generator'

module VCAP::CloudController
  class EventListFetcher
    class << self
      def fetch_all(message, event_dataset)
        filter(message, event_dataset)
      end

      private

      def filter(message, dataset)
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

        if message.requested?(:created_at)
          key = message.created_at.keys[0]
          if key == Event::LESS_THAN_COMPARATOR
            dataset = dataset.where(Sequel.lit("created_at < '#{Time.parse(message.created_at[key]).utc}'"))
          elsif key == Event::LESS_THAN_OR_EQUAL_COMPARATOR
            dataset = dataset.where(Sequel.lit("created_at <= '#{Time.parse(message.created_at[key]).utc}'"))
          elsif key == Event::GREATER_THAN_COMPARATOR
            dataset = dataset.where(Sequel.lit("created_at > '#{Time.parse(message.created_at[key]).utc}'"))
          elsif key == Event::GREATER_THAN_OR_EQUAL_COMPARATOR
            dataset = dataset.where(Sequel.lit("created_at >= '#{Time.parse(message.created_at[key]).utc}'"))
          end
        end

        dataset
      end
    end
  end
end
