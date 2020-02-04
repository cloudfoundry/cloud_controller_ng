require 'messages/space_quota_update_message'
require 'messages/validators'

module VCAP::CloudController
  class SpaceQuotasCreateMessage < SpaceQuotaUpdateMessage
    register_allowed_keys [:relationships]

    validates_with RelationshipValidator

    validates :name, presence: true

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
