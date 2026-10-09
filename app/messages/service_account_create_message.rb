require 'messages/metadata_base_message'

module VCAP::CloudController
  class ServiceAccountCreateMessage < MetadataBaseMessage
    register_allowed_keys %i[name relationships description]
    validates :description, string: true, allow_nil: true, length: { maximum: 250 }
    validates_with NoAdditionalKeysValidator, RelationshipValidator
    validates :name, presence: true, string: true,
                     format: { with: ->(_) { ServiceAccountModel::NAME_PATTERN } }, length: { in: 3..63 }

    delegate :space_guid, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships.deep_symbolize_keys)
    end

    class Relationships < BaseMessage
      register_allowed_keys [:space]
      validates_with NoAdditionalKeysValidator
      validates :space, presence: true, to_one_relationship: true

      def space_guid
        HashUtils.dig(space, :data, :guid)
      end
    end
  end
end
