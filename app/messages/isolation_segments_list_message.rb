require 'messages/list_message'

module VCAP::CloudController
  class IsolationSegmentsListMessage < ListMessage
    register_allowed_keys [
      :names,
      :guids,
      :organization_guids,
      # order_direction is a legacy query filter from V2 and should not be propagated to new V3 messages
      # V3 endpoints use '+' or '-' prefixes to determine order direction
      :order_direction,
    ]

    validates_with NoAdditionalParamsValidator

    validates :names, array: true, allow_nil: true
    validates :guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true

    def self.from_params(params)
      opts = params.dup
      %w(names guids organization_guids).each do |attribute|
        to_array! opts, attribute
      end
      new(opts.symbolize_keys)
    end

    def valid_order_by_values
      super << :name
    end
  end
end
