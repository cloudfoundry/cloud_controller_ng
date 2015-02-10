module VCAP::CloudController
  class PaginationOptions
    PAGE_DEFAULT      = 1
    PER_PAGE_DEFAULT  = 50
    PER_PAGE_MAX      = 5000
    SORT_DEFAULT      = 'id'
    DIRECTION_DEFAULT = 'asc'
    VALID_DIRECTIONS  = %w(asc desc)

    attr_reader :page, :per_page, :sort, :direction

    def initialize(options)
      @page      = options[:page] || PAGE_DEFAULT
      @per_page  = options[:per_page] || PER_PAGE_DEFAULT
      @sort      = options[:sort] || SORT_DEFAULT
      @direction = options[:direction]

      @page = PAGE_DEFAULT if @page <= 0
      @per_page = PER_PAGE_DEFAULT if @per_page > PER_PAGE_MAX || @per_page <= 0
      @direction = DIRECTION_DEFAULT if !VALID_DIRECTIONS.include?(@direction)
    end

    def self.from_params(params)
      page     = params['page'].to_i
      per_page = params['per_page'].to_i
      sort = params['sort']
      direction = params['direction']
      options = { page: page, per_page: per_page, sort: sort, direction: direction }
      PaginationOptions.new(options)
    end

    def keys
      [:page, :per_page, :sort, :direction]
    end
  end
end
