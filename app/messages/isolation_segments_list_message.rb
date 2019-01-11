require 'messages/list_message'
require 'messages/validators/label_selector_requirement_validator'

module VCAP::CloudController
  class IsolationSegmentsListMessage < ListMessage
    register_allowed_keys [
      :names,
      :guids,
      :organization_guids,
      :label_selector,
    ]

    validates_with NoAdditionalParamsValidator
    validates_with LabelSelectorRequirementValidator, if: label_selector_requested?

    validates :names, array: true, allow_nil: true
    validates :guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(names guids organization_guids))
    end

    def valid_order_by_values
      super << :name
    end
  end
end
