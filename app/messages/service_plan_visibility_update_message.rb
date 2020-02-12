require 'messages/metadata_list_message'
require 'messages/validators/label_selector_requirement_validator'

module VCAP::CloudController
  class ServicePlanVisibilityUpdateMessage < BaseMessage
    register_allowed_keys [
      :type
    ]

    validates_with NoAdditionalParamsValidator
    validates :type, inclusion: { in: %w(public admin organization), message: "must be one of 'public', 'admin', 'organization'" }, allow_nil: false

    def self.from_params(params)
      super(params, [])
    end
  end
end
