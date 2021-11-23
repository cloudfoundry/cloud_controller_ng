require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class SequelPaginator
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

      records, count = if sequel_dataset.supports_window_functions? && !sequel_dataset.opts[:distinct]
                         paginate_with_window_function(sequel_dataset, per_page, page, table_name)
                       else
                         paginate_with_extension(sequel_dataset, per_page, page)
                       end

      PaginatedResult.new(records, count, pagination_options)
    end

    private

    def paginate_with_window_function(dataset, per_page, page, table_name)
      dataset = dataset.limit(per_page, (page - 1) * per_page)
      if dataset.opts[:graph]
        dataset = dataset.add_graph_aliases(pagination_total_results: [table_name, :pagination_total_results, Sequel.function(:count).*.over])
      else
        dataset = dataset.select_append(Sequel.as(Sequel.function(:count).*.over, :pagination_total_results))
      end
      records = dataset.all
      count = records.any? ? records.first[:pagination_total_results] : 0
      records.each { |x| x.values.delete(:pagination_total_results) }
      return records, count
    end

    def paginate_with_extension(dataset, per_page, page)
      query = dataset.extension(:pagination).paginate(page, per_page)
      return query.all, query.pagination_record_count
    end
  end
end
