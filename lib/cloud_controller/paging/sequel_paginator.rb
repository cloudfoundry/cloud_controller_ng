require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class SequelPaginator
    def get_page(sequel_dataset, pagination_options)
      page = pagination_options.page
      per_page = pagination_options.per_page
      order_by = pagination_options.order_by
      order_direction = pagination_options.order_direction

      table_name = sequel_dataset.model.table_name
      # DISTINCT requires sorting the table. This is much faster to do for just the primary key which is all that is needed for COUNT
      record_count = if sequel_dataset.opts.key?(:distinct)
                       pk_column_name = "#{table_name}__#{sequel_dataset.model.primary_key}".to_sym
                       sequel_dataset.select(pk_column_name).count
                     end
      column_name = "#{table_name}__#{order_by}".to_sym
      sequel_order = order_direction == 'asc' ? Sequel.asc(column_name) : Sequel.desc(column_name)

      if sequel_dataset.model.columns.include?(:guid)
        guid_column_name = "#{table_name}__guid".to_sym
        guid_sequel_order = Sequel.asc(guid_column_name)
        query = sequel_dataset.extension(:pagination).paginate(page, per_page, record_count).order(sequel_order, guid_sequel_order)
      else
        query = sequel_dataset.extension(:pagination).paginate(page, per_page, record_count).order(sequel_order)
      end

      PaginatedResult.new(query.all, query.pagination_record_count, pagination_options)
    end
  end
end
