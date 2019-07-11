module VCAP::CloudController
  class NullFilterQueryGenerator
    class << self
      def add_filter(resource_dataset, key, filter_values)
        non_empty_values = filter_values.reject(&:empty?)
        include_null = non_empty_values.length < filter_values.length

        filter = if include_null
                   Sequel.or([[key, non_empty_values], [key, nil]])
                 else
                   { key => non_empty_values }
                 end

        resource_dataset.where(filter)
      end
    end
  end
end
