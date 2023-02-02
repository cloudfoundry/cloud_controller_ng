require 'models/helpers/relational_operators'

module VCAP::CloudController
  class BaseListFetcher
    class << self
      def filter(message, dataset, klass)
        dataset = advanced_filtering(message, dataset, klass)

        if message.requested?(:guids)
          dataset = dataset.where("#{klass.table_name}__guid": message.guids)
        end

        dataset
      end

      def advanced_filtering(message, dataset, klass)
        advanced_filters = {}
        advanced_filters['created_at'] = message.created_ats if message.requested?(:created_ats)
        advanced_filters['updated_at'] = message.updated_ats if message.requested?(:updated_ats)

        advanced_filters.each do |filter, values|
          if values.is_a?(Hash)
            values.map do |operator, given_timestamp|
              if operator == RelationalOperators::LESS_THAN_COMPARATOR
                normalized_timestamp = Time.parse(given_timestamp).utc
                dataset = dataset.where(Sequel.qualify(klass.table_name, filter) < normalized_timestamp)
              elsif operator == RelationalOperators::LESS_THAN_OR_EQUAL_COMPARATOR
                normalized_timestamp = (Time.parse(given_timestamp).utc + 0.999999).utc
                dataset = dataset.where(Sequel.qualify(klass.table_name, filter) <= normalized_timestamp)
              elsif operator == RelationalOperators::GREATER_THAN_COMPARATOR
                normalized_timestamp = (Time.parse(given_timestamp).utc + 0.999999).utc
                dataset = dataset.where(Sequel.qualify(klass.table_name, filter) > normalized_timestamp)
              elsif operator == RelationalOperators::GREATER_THAN_OR_EQUAL_COMPARATOR
                normalized_timestamp = Time.parse(given_timestamp).utc
                dataset = dataset.where(Sequel.qualify(klass.table_name, filter) >= normalized_timestamp)
              end
            end
          else
            # Gotcha: unlike the other relational operators, which are hashes such as
            # { lt: '2020-06-30T12:34:56Z' }, the equals operator is simply an array, e.g.
            # [ '2020-06-30T12:34:56Z' ].
            # Gotcha: the equals operator returns all resources occurring within
            # the span of the second (e.g. "12:34:56.00-12:34:56.9999999"), for databases store
            # timestamps in sub-second accuracy (PostgreSQL stores in microseconds, for example)

            bounds_expressions = values.map do |timestamp|
              lower_bound = Time.parse(timestamp).utc
              upper_bound = Time.at(lower_bound + 0.999999).utc

              (Sequel.qualify(klass.table_name, filter) <= upper_bound) &
              (Sequel.qualify(klass.table_name, filter) >= lower_bound)
            end

            dataset = dataset.where(Sequel.|(*bounds_expressions))
          end
        end
        dataset
      end
    end
  end
end
