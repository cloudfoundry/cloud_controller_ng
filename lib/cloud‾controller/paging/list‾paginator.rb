module VCAP::CloudController
  class ListPaginator
    def get_page(list_dataset, pagination_options)
      page = pagination_options.page
      per_page = pagination_options.per_page
      order_by = pagination_options.order_by
      order_direction = pagination_options.order_direction

      sorted_list = sort_list(list_dataset, order_by, order_direction)
      records = paginate_list(sorted_list, page, per_page)
      total = list_dataset.length

      PaginatedResult.new(records, total, pagination_options)
    end

    private

    def sort_list(list, order_by_method, order_direction)
      sorted_list = list.sort do |object1, object2|
        value1 = object1.public_send(order_by_method)
        value2 = object2.public_send(order_by_method)
        next 0 if value1.nil? && value2.nil?
        next -1 if value1.nil?
        next 1 if value2.nil?

        value1 <=> value2
      end

      if order_direction != VCAP::CloudController::PaginationOptions::DIRECTION_DEFAULT
        sorted_list.reverse!
      end

      sorted_list
    end

    def paginate_list(list, page_number, page_size)
      start_index = page_size * (page_number - 1)
      end_index = start_index + page_size - 1
      list[start_index..end_index] || []
    end
  end
end
