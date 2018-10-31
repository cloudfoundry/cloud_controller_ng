require 'messages/base_message'
require 'messages/validators/metadata_validator'

module VCAP::CloudController
  class OrganizationCreateMessage < BaseMessage
    register_allowed_keys [:name, :metadata]

    def self.metadata_requested?
      @metadata_requested ||= proc { |a| a.requested?(:metadata) }
    end

    validates_with NoAdditionalKeysValidator
    validates_with MetadataValidator, if: metadata_requested?

    validates :name, presence: true
    validates :name,
      string: true,
      length: { maximum: 255 },
      format: { with: ->(_) { Organization::ORG_NAME_REGEX }, message: 'must not contain escaped characters' },
      allow_nil: true

    def labels
      HashUtils.dig(metadata, :labels)
    end
  end
end
