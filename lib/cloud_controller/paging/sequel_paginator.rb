module VCAP::CloudController
  class SequelPaginator
    PAGE_DEFAULT     = 1
    PER_PAGE_DEFAULT = 50
    PER_PAGE_MAX     = 5000

    def get_page(sequel_dataset, pagination_request)
      page = pagination_request.page.nil? ? PAGE_DEFAULT : pagination_request.page
      page = PAGE_DEFAULT if page < 1

      per_page = pagination_request.per_page.nil? ? PER_PAGE_DEFAULT : pagination_request.per_page
      per_page = PER_PAGE_DEFAULT if per_page < 1
      per_page = PER_PAGE_MAX if per_page > PER_PAGE_MAX

      query = sequel_dataset.extension(:pagination).paginate(page, per_page).order(:id)

      PaginatedResult.new(query.all, query.pagination_record_count, page, per_page)
    end
  end
end
