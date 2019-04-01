require 'messages/list_message'
require 'messages/validators/label_selector_requirement_validator'

module VCAP::CloudController
  class AppBuildsListMessage < ListMessage
    register_allowed_keys [
      :states,
      :label_selector,
    ]

    validates_with NoAdditionalParamsValidator
    validates_with LabelSelectorRequirementValidator, if: label_selector_requested?

    validates :states, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(states))
    end
  end
end
