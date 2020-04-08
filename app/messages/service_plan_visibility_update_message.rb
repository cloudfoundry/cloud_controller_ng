require 'messages/metadata_list_message'
require 'messages/validators/label_selector_requirement_validator'

module VCAP::CloudController
  class ServicePlanVisibilityUpdateMessage < BaseMessage
    register_allowed_keys [
      :type,
      :organizations
    ]

    validates_with NoAdditionalKeysValidator

    validates :type,
      allow_nil: false,
      inclusion: {
        in: %w(public admin organization),
        message: "must be one of 'public', 'admin', 'organization'"
      }
    validates :organizations,
      if: -> { type == 'organization' },
      array: true,
      presence: true,
      org_visibility: true
    validates :organizations,
      unless: -> { type == 'organization' },
      absence: true

    def self.from_params(params)
      super(params, [])
    end
  end
end
