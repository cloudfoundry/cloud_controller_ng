require 'messages/base_message'

module VCAP::CloudController
  class OrganizationCreateMessage < BaseMessage
    register_allowed_keys [:name]

    validates_with NoAdditionalKeysValidator
    validates :name, presence: true
    validates :name,
      string: true,
      length: { maximum: 255 },
      format: { with: ->(_) { Organization::ORG_NAME_REGEX }, message: 'must not contain escaped characters' },
      allow_nil: true
  end
end
