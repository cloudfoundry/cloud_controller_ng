require 'messages/list_message'
require 'messages/validators/label_selector_requirement_validator'

module VCAP::CloudController
  class BuildpacksListMessage < ListMessage
    register_allowed_keys [
      :stacks,
      :names,
      :label_selector,
      :page,
      :per_page,
    ]

    validates :names, array: true, allow_nil: true
    validates :stacks, array: true, allow_nil: true

    validates_with NoAdditionalParamsValidator
    validates_with LabelSelectorRequirementValidator, if: label_selector_requested?

    def self.from_params(params)
      super(params, %w(names stacks))
    end

    def to_param_hash
      super(exclude: [:page, :per_page])
    end

    def valid_order_by_values
      super << :position
    end
  end
end
