module VCAP::RestAPI
  class RouteMappingQuery < Query
    def filtered_dataset
      filter_args_from_query.inject(@dataset) do |filter, cond|
        if cond.respond_to?(:str) && cond.str.starts_with?('app_guid')
          app_filter(filter, cond)
        else
          filter.filter(cond)
        end
      end
    end

    def app_filter(dataset, cond)
      dataset.where(cond)
    end

    private

    def query_filter(key, comparison, val)
      values = comparison == ' IN ' ? val.split(',') : [val]

      col_type = column_type(key)

      return query_datetime_values(key, values, comparison) if col_type == :datetime

      values = values.collect { |value| cast_query_value(col_type, key, value) }.compact
      if values.empty?
        { key => nil }
      else
        Sequel.lit("#{key} #{comparison} ?", values)
      end
    end
  end
end
