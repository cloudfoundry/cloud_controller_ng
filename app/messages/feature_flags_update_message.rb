require 'messages/metadata_base_message'
require 'messages/validators'

module VCAP::CloudController
  class FeatureFlagsUpdateMessage < MetadataBaseMessage
    register_allowed_keys [:custom_error_message, :enabled]
    validates_with NoAdditionalKeysValidator

    validates :enabled,
      inclusion: { in: [true, false], message: 'must be a boolean' },
      presence: true

    validates :custom_error_message,
      string: true,
      length: { maximum: 250 },
      allow_nil: true
  end
end
