module VCAP::CloudController::RestController
  class OrderApplicator
    def initialize(opts)
      @order_by = Array(opts[:order_by] || :id).map(&:to_sym) # symbols
      @order_direction = opts[:order_direction] || 'asc'
    end

    def apply(dataset)
      validate!

      if descending?
        @order_by.inject(dataset) do |ds, col|
          validate_column(ds, col)
          ds.order_more(Sequel.desc(col))
        end
      else
        @order_by.inject(dataset) do |ds, col|
          validate_column(ds, col)
          ds.order_more(Sequel.asc(col))
        end
      end
    end

    private

    def validate!
      unless %w(asc desc).include?(@order_direction)
        raise VCAP::Errors::ApiError.new_from_details(
                'BadQueryParameter',
                "order_direction must be 'asc' or 'desc' but was '#{@order_direction}'")
      end
    end

    def validate_column(ds, col)
      unless ds.columns.include?(col)
        raise VCAP::Errors::ApiError.new_from_details(
                'BadQueryParameter',
                "invalid request parameter '#{col}' in order_by")
      end
    end

    def descending?
      @order_direction.downcase == 'desc'
    end
  end
end
