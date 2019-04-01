require 'messages/list_message'
require 'messages/validators/label_selector_requirement_validator'

module VCAP::CloudController
  class ProcessesListMessage < ListMessage
    register_allowed_keys [
      :app_guid,
      :types,
      :space_guids,
      :organization_guids,
      :app_guids,
      :guids,
      :label_selector,
    ]

    validates_with NoAdditionalParamsValidator # from BaseMessage
    validates_with LabelSelectorRequirementValidator, if: label_selector_requested?

    validates :app_guids, array: true, allow_nil: true
    validate :app_nested_request, if: -> { app_guid.present? }

    def self.from_params(params)
      super(params, %w(types space_guids organization_guids app_guids guids))
    end

    def to_param_hash
      super(exclude: [:app_guid])
    end

    private

    def app_nested_request
      invalid_guids = []
      invalid_guids << :app_guids if app_guids
      invalid_guids << :organization_guids if organization_guids
      invalid_guids << :space_guids if space_guids
      errors.add(:base, "Unknown query parameter(s): '#{invalid_guids.join("', '")}'") if invalid_guids.present?
    end
  end
end
