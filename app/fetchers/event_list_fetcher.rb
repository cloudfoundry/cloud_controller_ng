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
          if message.created_at.is_a?(Hash)
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
          else
            # Gotcha: unlike the other relational operators, which are hashes such as
            # { lt: '2020-06-29T12:34:56-07:00' }, the equals operator is simply a value, e.g.
            # '2020-06-29T12:34:56-07:00'.
            # Gotcha: the equals operator returns all resources occurring within
            # the span of the second (e.g. "12:34:56.00-12:34:56.9999999"), for databases store
            # timestamps in sub-second accuracy (PostgreSQL stores in microseconds, for example)
            lower_bound = Time.parse(message.created_at).utc
            upper_bound = Time.at(lower_bound + 0.99999).utc
            dataset = dataset.where(Sequel.lit('created_at BETWEEN ? AND ?', lower_bound, upper_bound))
          end
        end

        dataset
      end
    end
  end
end
