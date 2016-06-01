require 'mappers/order_by_mapper'

module VCAP::CloudController
  module Presenters
    module V3
      class PaginationPresenter
        def present_pagination_hash(paginated_result, base_url, filters=nil)
          pagination_options = paginated_result.pagination_options

          last_page     = (paginated_result.total.to_f / pagination_options.per_page.to_f).ceil
          last_page     = 1 if last_page < 1
          previous_page = pagination_options.page - 1
          next_page     = pagination_options.page + 1

          order_params  = OrderByMapper.to_param_hash(pagination_options.order_by, pagination_options.order_direction)
          filter_params = filters.nil? ? {} : filters.to_param_hash
          params        = { per_page: pagination_options.per_page }.merge(order_params).merge(filter_params)

          first_uri    = URI::HTTP.build(path: base_url, query: params.merge({ page: 1 }).to_query).request_uri
          last_uri     = URI::HTTP.build(path: base_url, query: params.merge({ page: last_page }).to_query).request_uri
          next_uri     = URI::HTTP.build(path: base_url, query: params.merge({ page: next_page }).to_query).request_uri
          previous_uri = URI::HTTP.build(path: base_url, query: params.merge({ page: previous_page }).to_query).request_uri

          {
            total_results: paginated_result.total,
            total_pages:   last_page,

            first:         { href: first_uri },
            last:          { href: last_uri },
            next:          next_page <= last_page ? { href: next_uri } : nil,
            previous:      previous_page > 0 ? { href: previous_uri } : nil
          }
        end

        def present_unpagination_hash(result, base_url)
          {
            total_results: result.length,
            total_pages:   1,

            first:         { href: base_url },
            last:          { href: base_url },
            next:          nil,
            previous:      nil
          }
        end
      end
    end
  end
end
