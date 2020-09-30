require 'messages/list_message'

module VCAP::CloudController
  class FeatureFlagsListMessage < ListMessage
    validates_with NoAdditionalParamsValidator
    validates_with DisallowCreatedAtsParamValidator

    def self.from_params(params)
      super(params, [])
    end

    def initialize(params={})
      super
      pagination_options.default_order_by = 'name'
    end

    def valid_order_by_values
      [:name]
    end
  end
end
