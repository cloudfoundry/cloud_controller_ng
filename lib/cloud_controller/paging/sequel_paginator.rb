require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class SequelPaginator
    def get_page(dataset, pagination_options)
      page = pagination_options.page
      per_page = pagination_options.per_page
      order_direction = pagination_options.order_direction
      order_by = pagination_options.order_by
      table_name = dataset.model.table_name
      has_guid_column = dataset.model.columns.include?(:guid)

      order_type = Sequel.send(order_direction, Sequel.qualify(table_name, order_by))
      dataset = dataset.order(order_type)

      dataset = dataset.order_append(Sequel.send(order_direction, Sequel.qualify(table_name, :guid))) if order_by != 'id' && has_guid_column

      records, count = if can_paginate_with_window_function?(dataset)
                         paginate_with_window_function(dataset, per_page, page, table_name)
                       else
                         paginate_with_extension(dataset, per_page, page)
                       end

      PaginatedResult.new(records, count, pagination_options)
    end

    def can_paginate_with_window_function?(dataset)
      dataset.supports_window_functions? && (!dataset.opts[:distinct] || !dataset.requires_unique_column_names_in_subquery_select_list?)
    end

    private

    def paginate_with_window_function(dataset, per_page, page, table_name)
      dataset = dataset.from_self if dataset.opts[:distinct]
      dataset = if dataset.opts[:graph]
                  dataset.add_graph_aliases(pagination_total_results: [table_name, :pagination_total_results, Sequel.function(:count).*.over])
                else
                  dataset.select_append(Sequel.as(Sequel.function(:count).*.over, :pagination_total_results))
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
