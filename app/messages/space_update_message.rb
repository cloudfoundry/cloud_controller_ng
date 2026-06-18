require 'messages/metadata_base_message'

module VCAP::CloudController
  class SpaceUpdateMessage < MetadataBaseMessage
    register_allowed_keys %i[name suspended]

    validates_with NoAdditionalKeysValidator

    validates :name,
              string: true,
              length: { minimum: 1, maximum: 255 },
              format: { with: ->(_) { Space::SPACE_NAME_REGEX }, message: 'must not contain escaped characters' },
              allow_nil: true

    validates :suspended,
              boolean: true,
              allow_nil: true
  end
end
