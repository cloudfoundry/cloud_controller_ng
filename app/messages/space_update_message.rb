require 'messages/base_message'

module VCAP::CloudController
  class SpaceUpdateMessage < BaseMessage
    register_allowed_keys [:name]

    validates_with NoAdditionalKeysValidator

    validates :name,
      string: true,
      length: { minimum: 1, maximum: 255 },
      format: { with: ->(_) { Space::SPACE_NAME_REGEX }, message: 'must not contain escaped characters' },
      allow_nil: true
  end
end
