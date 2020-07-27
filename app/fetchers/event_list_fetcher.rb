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

        advanced_filters = {}
        advanced_filters['created_at'] = message.created_ats if message.requested?(:created_ats)
        advanced_filters['updated_at'] = message.updated_ats if message.requested?(:updated_ats)

        advanced_filters.each do |filter, values|
          puts "filter: #{filter}"
          puts "values: #{values}"
          puts "db: #{Event.alls.map(&:updated_at)}"
          if values.is_a?(Hash)
            values.map do |operator, given_timestamp|
              if operator == Event::LESS_THAN_COMPARATOR
                normalized_timestamp = Time.parse(given_timestamp).utc
                dataset = dataset.where(Sequel.lit("#{filter} < ?", normalized_timestamp))
              elsif operator == Event::LESS_THAN_OR_EQUAL_COMPARATOR
                normalized_timestamp = (Time.parse(given_timestamp).utc + 0.999999).utc
                dataset = dataset.where(Sequel.lit("#{filter} <= ?", normalized_timestamp))
              elsif operator == Event::GREATER_THAN_COMPARATOR
                puts 'I should be here'
                normalized_timestamp = (Time.parse(given_timestamp).utc + 0.999999).utc
                dataset = dataset.where(Sequel.lit("#{filter} > ?", normalized_timestamp))
              elsif operator == Event::GREATER_THAN_OR_EQUAL_COMPARATOR
                normalized_timestamp = Time.parse(given_timestamp).utc
                dataset = dataset.where(Sequel.lit("#{filter} >= ?", normalized_timestamp))
              end
            end
          else
            # Gotcha: unlike the other relational operators, which are hashes such as
            # { lt: '2020-06-30T12:34:56Z' }, the equals operator is simply an array, e.g.
            # [ '2020-06-30T12:34:56Z' ].
            # Gotcha: the equals operator returns all resources occurring within
            # the span of the second (e.g. "12:34:56.00-12:34:56.9999999"), for databases store
            # timestamps in sub-second accuracy (PostgreSQL stores in microseconds, for example)
            sequel_query =
              (['created_at BETWEEN ? AND ?'] * values.size).join(' OR ')

            times = values.map do |created_at|
              lower_bound = Time.parse(created_at).utc
              upper_bound = Time.at(lower_bound + 0.999999).utc
              [lower_bound, upper_bound]
            end.flatten

            dataset = dataset.where(Sequel.lit(sequel_query, *times))
          end
        end

        dataset
      end
    end
  end
end
