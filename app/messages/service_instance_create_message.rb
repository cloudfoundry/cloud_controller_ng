require 'messages/metadata_base_message'
require 'utils/hash_utils'

module VCAP::CloudController
  class ServiceInstanceCreateMessage < MetadataBaseMessage
    register_allowed_keys [:type, :relationships]

    validates_with RelationshipValidator
    validates_with NoAdditionalKeysValidator
    validates :type, allow_blank: false, inclusion: {
        in: %w(managed user-provided),
        message: "must be one of 'managed', 'user-provided'"
      }

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    delegate :space_guid, to: :relationships_message

    class Relationships < BaseMessage
      register_allowed_keys [:space]

      validates_with NoAdditionalKeysValidator

      validates :space, presence: true, allow_nil: false, to_one_relationship: true

      def space_guid
        HashUtils.dig(space, :data, :guid)
      end
    end
  end
end
