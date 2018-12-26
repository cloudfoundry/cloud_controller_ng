require 'messages/list_message'

module VCAP::CloudController
  class BuildpacksListMessage < ListMessage
    register_allowed_keys [
      :names,
      :page,
      :per_page,
    ]
    validates :names, array: true, allow_nil: true

    validates_with NoAdditionalParamsValidator

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
