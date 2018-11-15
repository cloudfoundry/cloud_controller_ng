require 'messages/list_message'

module VCAP::CloudController
  class StacksListMessage < ListMessage
    register_allowed_keys [
      :page,
      :per_page,
    ]

    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      super(params, %w())
    end

    def valid_order_by_values
      super << :name
    end
  end
end
