require 'messages/metadata_base_message'
require 'messages/validators'

module VCAP::CloudController
  class FeatureFlagsUpdateMessage < MetadataBaseMessage
    register_allowed_keys [:custom_error_message, :enabled]
    validates_with NoAdditionalKeysValidator

    def self.enabled_requested?
      @enabled_requested ||= proc { |a| a.requested?(:enabled) }
    end

    validates :enabled,
      boolean: true,
      if: enabled_requested?

    validates :custom_error_message,
      string: true,
      length: { minimum: 1, maximum: 250 },
      allow_nil: true
  end
end
