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
          operator = message.created_at.keys[0]
          given_timestamp = message.created_at.values[0]

          if operator == Event::LESS_THAN_COMPARATOR
            normalized_timestamp = Time.parse(given_timestamp).utc
            dataset = dataset.where(Sequel.lit('created_at < ?', normalized_timestamp))
          elsif operator == Event::LESS_THAN_OR_EQUAL_COMPARATOR
            normalized_timestamp = (Time.parse(given_timestamp).utc + 0.99999).utc
            dataset = dataset.where(Sequel.lit('created_at <= ?', normalized_timestamp))
          elsif operator == Event::GREATER_THAN_COMPARATOR
            normalized_timestamp = (Time.parse(given_timestamp).utc + 0.99999).utc
            dataset = dataset.where(Sequel.lit('created_at > ?', normalized_timestamp))
          elsif operator == Event::GREATER_THAN_OR_EQUAL_COMPARATOR
            normalized_timestamp = Time.parse(given_timestamp).utc
            dataset = dataset.where(Sequel.lit('created_at >= ?', normalized_timestamp))
          end
        end

        dataset
      end
    end
  end
end
