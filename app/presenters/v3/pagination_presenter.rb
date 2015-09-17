module VCAP::CloudController
  class PaginationPresenter
    def present_pagination_hash(paginated_result, base_url, filters=nil)
      pagination_options = paginated_result.pagination_options
      page          = pagination_options.page
      per_page      = pagination_options.per_page
      total_results = paginated_result.total

      last_page     = (total_results.to_f / per_page.to_f).ceil
      last_page     = 1 if last_page < 1
      previous_page = page - 1
      next_page     = page + 1

      order = paginated_order(pagination_options.order_by, pagination_options.order_direction)

      serialized_filters = filters.nil? ? '' : filters.to_params
      serialized_filters += '&' unless serialized_filters.empty?

      {
        total_results: total_results,
        first:         { href: "#{base_url}?#{serialized_filters}#{order}page=1&per_page=#{per_page}" },
        last:          { href: "#{base_url}?#{serialized_filters}#{order}page=#{last_page}&per_page=#{per_page}" },
        next:          next_page <= last_page ? { href: "#{base_url}?#{serialized_filters}#{order}page=#{next_page}&per_page=#{per_page}" } : nil,
        previous:      previous_page > 0 ? { href: "#{base_url}?#{serialized_filters}#{order}page=#{previous_page}&per_page=#{per_page}" } : nil,
      }
    end

    private

    def paginated_order(order_by, order_direction)
      if order_by == 'id'
        ''
      else
        prefix = order_direction == 'asc' ? '+' : '-'
        "order_by=#{prefix}#{order_by}&"
      end
    end
  end
end
