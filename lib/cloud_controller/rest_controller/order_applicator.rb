module VCAP::CloudController::RestController
  class OrderApplicator
    def initialize(opts)
      @order_by = (opts[:order_by] || :id).to_sym # symbols
    end

    def apply(dataset)
      dataset.order_by(@order_by)
    end
  end
end
