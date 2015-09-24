require 'mappers/order_by_mapper'

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

      order = OrderByMapper.to_param_hash(pagination_options.order_by, pagination_options.order_direction)
      pagination_params = { per_page: per_page }.merge(order)

      filter_params = filters.nil? ? '' : filters.to_params
      filter_params += '&' unless filter_params.empty?

      {
        total_results: total_results,

        first:    { href: "#{base_url}?#{filter_params}#{pagination_params.merge({ page: 1 }).to_query}" },
        last:     { href: "#{base_url}?#{filter_params}#{pagination_params.merge({ page: last_page }).to_query}" },
        next:     next_page <= last_page ? { href: "#{base_url}?#{filter_params}#{pagination_params.merge({ page: next_page }).to_query}" } : nil,
        previous: previous_page > 0 ? { href: "#{base_url}?#{filter_params}#{pagination_params.merge({ page: previous_page }).to_query}" } : nil,
      }
    end
  end
end
