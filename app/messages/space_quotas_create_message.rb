require 'messages/metadata_base_message'
require 'messages/validators'

module VCAP::CloudController
  class SpaceQuotasCreateMessage < BaseMessage
    MAX_SPACE_QUOTA_NAME_LENGTH = 250

    register_allowed_keys [:name, :relationships]
    validates_with NoAdditionalKeysValidator
    validates_with RelationshipValidator

    validates :name,
      string: true,
      presence: true,
      length: { maximum: MAX_SPACE_QUOTA_NAME_LENGTH }

    # Relationships validations
    delegate :organization_guid, to: :relationships_message
    delegate :space_guids, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    class Relationships < BaseMessage
      register_allowed_keys [:organization, :spaces]

      validates :organization, allow_nil: false, to_one_relationship: true
      validates :spaces, allow_nil: true, to_many_relationship: true

      def initialize(params)
        super(params)
      end

      def organization_guid
        HashUtils.dig(organization, :data, :guid)
      end

      def space_guids
        space_data = HashUtils.dig(spaces, :data)
        space_data ? space_data.map { |space| space[:guid] } : []
      end
    end
  end
end
