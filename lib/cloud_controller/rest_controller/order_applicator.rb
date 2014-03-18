module VCAP::CloudController::RestController
  class OrderApplicator
    def initialize(opts)
      @order_by = (opts[:order_by] || :id).to_sym # symbols
      @order_direction = opts[:order_direction] || "asc"
    end

    def apply(dataset)
      validate!

      if descending?
        dataset.order(Sequel.desc(@order_by))
      else
        dataset.order(Sequel.asc(@order_by))
      end
    end

    private

    def validate!
      unless %w(asc desc).include?(@order_direction)
        raise VCAP::Errors::ApiError.new_from_details(
                "BadQueryParameter",
                "order_direction must be 'asc' or 'desc' but was '#{@order_direction}'")
      end
    end

    def descending?
      @order_direction.downcase == "desc"
    end
  end
end
