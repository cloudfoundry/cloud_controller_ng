require 'messages/base_message'
require 'messages/validators/metadata_validator'

module VCAP::CloudController
  class SpaceCreateMessage < BaseMessage
    register_allowed_keys [:name, :relationships, :metadata]

    def self.metadata_requested?
      @metadata_requested ||= proc { |a| a.requested?(:metadata) }
    end

    validates_with NoAdditionalKeysValidator,
      RelationshipValidator
    validates_with MetadataValidator, if: metadata_requested?

    validates :name, presence: true
    validates :name,
      string: true,
      length: { maximum: 255 },
      format: { with: ->(_) { Space::SPACE_NAME_REGEX }, message: 'must not contain escaped characters' },
      allow_nil: true

    delegate :organization_guid, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships.deep_symbolize_keys)
    end

    def labels
      HashUtils.dig(metadata, :labels)
    end

    class Relationships < BaseMessage
      register_allowed_keys [:organization]

      validates_with NoAdditionalKeysValidator

      validates :organization, presence: true, allow_nil: false, to_one_relationship: true

      def organization_guid
        HashUtils.dig(organization, :data, :guid)
      end
    end
  end
end
