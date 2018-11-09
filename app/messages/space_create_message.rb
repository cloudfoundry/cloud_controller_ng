require 'messages/metadata_base_message'

module VCAP::CloudController
  class SpaceCreateMessage < MetadataBaseMessage
    register_allowed_keys [:name, :relationships]

    validates_with NoAdditionalKeysValidator,
      RelationshipValidator

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
