require 'messages/list_message'

module VCAP::CloudController
  class StacksListMessage < ListMessage
    register_allowed_keys [
      :names,
      :page,
      :per_page,
    ]

    validates_with NoAdditionalParamsValidator

    validates :names, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(names))
    end

    def to_param_hash
      super(exclude: [:page, :per_page])
    end

    def valid_order_by_values
      super << :name
    end
  end
end
