require 'messages/metadata_base_message'

module VCAP::CloudController
  class StackUpdateMessage < MetadataBaseMessage
    register_allowed_keys %i[deprecated_at locked_at disabled_at]

    validates :deprecated_at, timestamp: true, allow_nil: true
    validates :locked_at, timestamp: true, allow_nil: true
    validates :disabled_at, timestamp: true, allow_nil: true
  end
end
