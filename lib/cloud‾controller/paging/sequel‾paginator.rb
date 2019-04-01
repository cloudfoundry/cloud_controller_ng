module VCAP::CloudController
  class SequelPaginator
    def get_page(sequel_dataset, pagination_options)
      page = pagination_options.page
      per_page = pagination_options.per_page
      order_by = pagination_options.order_by
      order_direction = pagination_options.order_direction

      table_name = sequel_dataset.model.table_name
      column_name = "#{table_name}__#{order_by}".to_sym
      sequel_order = order_direction == 'asc' ? Sequel.asc(column_name) : Sequel.desc(column_name)
      query = sequel_dataset.extension(:pagination).paginate(page, per_page).order(sequel_order)

      PaginatedResult.new(query.all, query.pagination_record_count, pagination_options)
    end
  end
end
