require 'messages/list_message'

module VCAP::CloudController
  class ServiceUsageSnapshotsListMessage < ListMessage
    register_allowed_keys []

    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      super(params, [])
    end

    def valid_order_by_values
      super + [:created_at]
    end
  end
end
