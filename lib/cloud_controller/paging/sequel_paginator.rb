module VCAP::CloudController
  class SequelPaginator
    def get_page(sequel_dataset, pagination_options)
      page = pagination_options.page
      per_page = pagination_options.per_page
      sort = pagination_options.sort
      direction = pagination_options.direction

      table_name = sequel_dataset.model.table_name
      column_name = "#{table_name}__#{sort}".to_sym
      sequel_order = direction == 'asc' ? Sequel.asc(column_name) : Sequel.desc(column_name)
      query = sequel_dataset.extension(:pagination).paginate(page, per_page).order(sequel_order)

      PaginatedResult.new(query.all, query.pagination_record_count, pagination_options)
    end
  end
end
