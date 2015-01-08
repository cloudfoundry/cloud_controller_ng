module VCAP::CloudController
  class PaginationPresenter
    def present_pagination_hash(paginated_result, base_url)
      page          = paginated_result.pagination_options.page
      per_page      = paginated_result.pagination_options.per_page
      total_results = paginated_result.total

      last_page     = (total_results.to_f / per_page.to_f).ceil
      last_page     = 1 if last_page < 1
      previous_page = page - 1
      next_page     = page + 1

      {
        total_results: total_results,
        first:         { href: "#{base_url}?page=1&per_page=#{per_page}" },
        last:          { href: "#{base_url}?page=#{last_page}&per_page=#{per_page}" },
        next:          next_page <= last_page ? { href: "#{base_url}?page=#{next_page}&per_page=#{per_page}" } : nil,
        previous:      previous_page > 0 ? { href: "#{base_url}?page=#{previous_page}&per_page=#{per_page}" } : nil,
      }
    end
  end
end
