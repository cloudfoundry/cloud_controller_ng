require 'messages/list_message'

module VCAP::CloudController
  class FeatureFlagsListMessage < ListMessage
    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      super(params, [])
    end

    def initialize(params={})
      super
      pagination_options.default_order_by = 'name'
    end
  end
end
