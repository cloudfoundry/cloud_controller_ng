module VCAP::CloudController
  class PaginationOptions
    PAGE_DEFAULT      = 1
    PER_PAGE_DEFAULT  = 50
    PER_PAGE_MAX      = 5000
    ORDER_DEFAULT     = 'id'
    DIRECTION_DEFAULT = 'asc'
    VALID_DIRECTIONS  = %w(asc desc)

    attr_reader :page, :per_page, :order_by, :order_direction

    def initialize(options)
      @page            = options[:page] || PAGE_DEFAULT
      @per_page        = options[:per_page] || PER_PAGE_DEFAULT
      @order_by        = options[:order_by] || ORDER_DEFAULT
      @order_direction = options[:order_direction]

      @page = PAGE_DEFAULT if @page <= 0
      @per_page = PER_PAGE_DEFAULT if @per_page > PER_PAGE_MAX || @per_page <= 0
      @order_direction = DIRECTION_DEFAULT if !VALID_DIRECTIONS.include?(@order_direction)
    end

    def self.from_params(params)
      page            = params['page'].to_i
      per_page        = params['per_page'].to_i
      order_by        = params['order_by']
      order_direction = params['order_direction']
      options = { page: page, per_page: per_page, order_by: order_by, order_direction: order_direction }
      PaginationOptions.new(options)
    end

    def keys
      [:page, :per_page, :order_by, :order_direction]
    end
  end
end
