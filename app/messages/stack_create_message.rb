require 'messages/metadata_base_message'

module VCAP::CloudController
  class StackCreateMessage < MetadataBaseMessage
    register_allowed_keys %i[name description deprecated_at locked_at disabled_at]

    validates :name, presence: true, length: { maximum: 250 }
    validates :description, length: { maximum: 250 }
    validates :deprecated_at, timestamp: true, allow_nil: true
    validates :locked_at, timestamp: true, allow_nil: true
    validates :disabled_at, timestamp: true, allow_nil: true
  end
end
