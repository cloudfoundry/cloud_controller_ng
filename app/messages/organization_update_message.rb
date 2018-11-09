require 'messages/metadata_base_message'

module VCAP::CloudController
  class OrganizationUpdateMessage < MetadataBaseMessage
    register_allowed_keys [:name]

    validates_with NoAdditionalKeysValidator

    validates :name,
      string: true,
      length: { minimum: 1, maximum: 255 },
      format: { with: ->(_) { Organization::ORG_NAME_REGEX }, message: 'must not contain escaped characters' },
      allow_nil: true
  end
end
