require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class SequelPaginator
    def get_page(dataset, pagination_options)
      page = pagination_options.page
      per_page = pagination_options.per_page
      order_direction = pagination_options.order_direction
      order_by = pagination_options.order_by.to_sym
      table_name = dataset.model.table_name

      # 1. Order the dataset by the specified column and direction.
      dataset = dataset.order(Sequel.send(order_direction, Sequel.qualify(table_name, order_by)))

      # 2. When ordering by 'created_at', add another order by 'id' to ensure a chronological order of records with the same 'created_at' timestamp.
      dataset = dataset.order_append(Sequel.send(order_direction, Sequel.qualify(table_name, :id))) if order_by == :created_at && has_column?(dataset, :id)

      # 3. Add a secondary order in case 'secondary_default_order_by' is specified and no custom order has been provided.
      secondary_order_by = pagination_options.secondary_order_by
      dataset = dataset.order_append(Sequel.send(order_direction, Sequel.qualify(table_name, secondary_order_by))) if secondary_order_by

      # 4. If the dataset is not already ordered by a unique column, add another order by 'guid' to ensure a deterministic ordering of records.
      if !order_includes_unique_column?(dataset.opts[:order]) && has_column?(dataset, :guid)
        dataset = dataset.order_append(Sequel.send(order_direction, Sequel.qualify(table_name, :guid)))
      end

      distinct_opt = dataset.opts[:distinct]
      if !distinct_opt.nil? && !distinct_opt.empty? # DISTINCT ON
        order_opt = dataset.opts[:order]
        dataset = if order_includes_unique_column?(order_opt)
                    # If ORDER BY columns are unique, use them for the DISTINCT ON clause.
                    dataset.distinct(*order_opt.map(&:expression))
                  else
                    # Otherwise, use DISTINCT.
                    dataset.distinct
                  end
      end

      records, count = if can_paginate_with_window_function?(dataset)
                         paginate_with_window_function(dataset, per_page, page, table_name)
                       else
                         paginate_with_extension(dataset, per_page, page, table_name)
                       end

      PaginatedResult.new(records, count, pagination_options)
    end

    def can_paginate_with_window_function?(dataset)
      enable_paginate_window = Config.config.get(:db, :enable_paginate_window).nil? || Config.config.get(:db, :enable_paginate_window)

      enable_paginate_window && dataset.supports_window_functions? && (!dataset.opts[:distinct] || !dataset.requires_unique_column_names_in_subquery_select_list?)
    end

    private

    def has_column?(dataset, column_name)
      dataset.model.columns.include?(column_name)
    end

    def order_includes_unique_column?(order_opt)
      order_opt.any? { |o| %i[id guid].include?(o.expression.column.to_sym) }
    end

    def paginate_with_window_function(dataset, per_page, page, table_name)
      dataset = dataset.from_self if dataset.opts[:distinct]

      paged_dataset = dataset.limit(per_page, (page - 1) * per_page)

      paged_dataset = if dataset.opts[:graph]
                        paged_dataset.add_graph_aliases(pagination_total_results: [table_name, :pagination_total_results, Sequel.function(:count).*.over])
                      elsif from_is_table?(dataset)
                        dataset.join_table(
                          :inner,
                          paged_dataset.select(Sequel[table_name][:id].as(:tmp_deferred_id)).
                              select_append(Sequel.as(Sequel.function(:count).*.over, :pagination_total_results)).
                              as(:tmp_deferred_table),
                          Sequel[table_name][:id] => Sequel[:tmp_deferred_table][:tmp_deferred_id]
                        ).select_append(:pagination_total_results)
                      else
                        paged_dataset.select_append(Sequel.as(Sequel.function(:count).*.over, :pagination_total_results))
                      end

      records = paged_dataset.all

      count = records.any? ? records.first[:pagination_total_results] : 0

      records.each do |x|
        x.values.delete(:pagination_total_results)
        x.values.delete(:tmp_deferred_id)
      end
      [records, count]
    end

    def paginate_with_extension(dataset, per_page, page, table_name)
      paged_dataset = dataset.extension(:pagination).paginate(page, per_page)
      count = paged_dataset.pagination_record_count

      if from_is_table?(dataset)
        paged_dataset = dataset.join_table(
          :inner,
          paged_dataset.select(Sequel[table_name][:id].as(:tmp_deferred_id)).as(:tmp_deferred_table),
          Sequel[table_name][:id] => Sequel[:tmp_deferred_table][:tmp_deferred_id]
        )
      end

      records = paged_dataset.all

      has_tmp_deferred_id = records.first&.keys&.include?(:tmp_deferred_id)
      records.each { |x| x.values.delete(:tmp_deferred_id) } if has_tmp_deferred_id

      [records, count]
    end

    def from_is_table?(dataset)
      [Symbol, String].include?(dataset.opts[:from].first.class)
    end
  end
end
