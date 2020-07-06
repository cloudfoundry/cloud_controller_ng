module VCAP::CloudController
  class BaseFetcher
    class << self
      private

      def filter(message, dataset)
        if message.requested?(:created_ats)
          if message.created_ats.is_a?(Hash)
            message.created_ats.map do |operator, given_timestamp|
              if operator == Event::LESS_THAN_COMPARATOR
                normalized_timestamp = Time.parse(given_timestamp).utc
                dataset = dataset.where(Sequel.lit('created_at < ?', normalized_timestamp))
              elsif operator == Event::LESS_THAN_OR_EQUAL_COMPARATOR
                normalized_timestamp = (Time.parse(given_timestamp).utc + 0.999999).utc
                dataset = dataset.where(Sequel.lit('created_at <= ?', normalized_timestamp))
              elsif operator == Event::GREATER_THAN_COMPARATOR
                normalized_timestamp = (Time.parse(given_timestamp).utc + 0.999999).utc
                dataset = dataset.where(Sequel.lit('created_at > ?', normalized_timestamp))
              elsif operator == Event::GREATER_THAN_OR_EQUAL_COMPARATOR
                normalized_timestamp = Time.parse(given_timestamp).utc
                dataset = dataset.where(Sequel.lit('created_at >= ?', normalized_timestamp))
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
              (['created_at BETWEEN ? AND ?'] * message.created_ats.size).join(' OR ')

            times = message.created_ats.map do |created_at|
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
