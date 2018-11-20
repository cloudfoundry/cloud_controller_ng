require 'messages/list_message'

module VCAP::CloudController
  class IsolationSegmentsListMessage < ListMessage
    register_allowed_keys [
      :names,
      :guids,
      :order_direction,
      :organization_guids,
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
