require 'messages/metadata_base_message'

module VCAP::CloudController
  class StackUpdateMessage < MetadataBaseMessage
    register_allowed_keys %i[deprecated_at locked_at disabled_at]

    validates_with NoAdditionalKeysValidator

    validates :deprecated_at, simple_timestamp: true, allow_nil: true
    validates :locked_at, simple_timestamp: true, allow_nil: true
    validates :disabled_at, simple_timestamp: true, allow_nil: true
  end
end
