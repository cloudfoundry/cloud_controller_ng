require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class SequelPaginator
    # Don't use window function for the 'events' table as this table might contain millions of rows
    # which can lead to a performance degradation.
    EXCLUDE_FROM_PAGINATION_WITH_WINDOW_FUNCTION = [:events].freeze
    def get_page(sequel_dataset, pagination_options)
      page = pagination_options.page
      per_page = pagination_options.per_page
      order_by = pagination_options.order_by
      order_direction = pagination_options.order_direction

      table_name = sequel_dataset.model.table_name
      column_name = Sequel.qualify(table_name, order_by)
      sequel_order = order_direction == 'asc' ? Sequel.asc(column_name) : Sequel.desc(column_name)

      sequel_dataset = sequel_dataset.order(sequel_order)
      sequel_dataset = sequel_dataset.order_append(Sequel.asc(Sequel.qualify(table_name, :guid))) if sequel_dataset.model.columns.include?(:guid)
      records, count = if !EXCLUDE_FROM_PAGINATION_WITH_WINDOW_FUNCTION.include?(table_name) && can_paginate_with_window_function?(sequel_dataset)
                         paginate_with_window_function(sequel_dataset, per_page, page, table_name)
                       else
                         paginate_with_extension(sequel_dataset, per_page, page)
                       end

      PaginatedResult.new(records, count, pagination_options)
    end

    def can_paginate_with_window_function?(dataset)
      dataset.supports_window_functions? && (!dataset.opts[:distinct] || !dataset.requires_unique_column_names_in_subquery_select_list?)
    end

    private

    def paginate_with_window_function(dataset, per_page, page, table_name)
      dataset = dataset.from_self if dataset.opts[:distinct]
      if dataset.opts[:graph]
        dataset = dataset.add_graph_aliases(pagination_total_results: [table_name, :pagination_total_results, Sequel.function(:count).*.over])
      else
        dataset = dataset.select_append(Sequel.as(Sequel.function(:count).*.over, :pagination_total_results))
      end
      records = dataset.limit(per_page, (page - 1) * per_page).all
      count = records.any? ? records.first[:pagination_total_results] : 0
      records.each { |x| x.values.delete(:pagination_total_results) }
      [records, count]
    end

    def paginate_with_extension(dataset, per_page, page)
      query = dataset.extension(:pagination).paginate(page, per_page)
      [query.all, query.pagination_record_count]
    end
  end
end
