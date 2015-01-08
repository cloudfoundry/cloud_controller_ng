module VCAP::CloudController
  class SequelPaginator
    PAGE_DEFAULT     = 1
    PER_PAGE_DEFAULT = 50
    PER_PAGE_MAX     = 5000

    def get_page(sequel_dataset, pagination_options)
      page = pagination_options.page.nil? ? PAGE_DEFAULT : pagination_options.page
      page = PAGE_DEFAULT if page < 1

      per_page = pagination_options.per_page.nil? ? PER_PAGE_DEFAULT : pagination_options.per_page
      per_page = PER_PAGE_DEFAULT if per_page < 1
      per_page = PER_PAGE_MAX if per_page > PER_PAGE_MAX

      query = sequel_dataset.extension(:pagination).paginate(page, per_page).order(:id)

      PaginatedResult.new(query.all, query.pagination_record_count, PaginationOptions.new(page, per_page))
    end
  end
end
