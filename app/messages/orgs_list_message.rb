require 'messages/list_message'
require 'messages/validators/label_selector_requirement_validator'

module VCAP::CloudController
  class OrgsListMessage < ListMessage
    register_allowed_keys [
      :page,
      :per_page,
      :names,
      :guids,
      :order_by,
      :isolation_segment_guid,
      :label_selector,
    ]

    validates_with NoAdditionalParamsValidator
    validates_with LabelSelectorRequirementValidator, if: label_selector_requested?

    validates :names, array: true, allow_nil: true
    validates :guids, array: true, allow_nil: true

    def to_param_hash
      super(exclude: [:page, :per_page, :order_by, :isolation_segment_guid])
    end

    def self.from_params(params)
      super(params, %w(names guids))
    end

    def valid_order_by_values
      super << :name
    end
  end
end
