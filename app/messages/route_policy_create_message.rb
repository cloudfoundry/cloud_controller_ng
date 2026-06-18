require 'messages/metadata_base_message'

module VCAP::CloudController
  class RoutePolicyCreateMessage < MetadataBaseMessage
    register_allowed_keys %i[
      source
      relationships
    ]

    validates_with NoAdditionalKeysValidator
    validates_with RelationshipValidator

    validates :source, presence: true, string: true

    validate :source_format_valid
    # cf:any exclusivity is enforced at the controller level when checking existing policies on the route

    delegate :route_guid, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    private

    def source_format_valid
      return unless source.is_a?(String)
      return if RoutePolicy::SOURCE_REGEX.match?(source)

      errors.add(:source, "must be in format 'cf:app:<uuid>', 'cf:space:<uuid>', 'cf:org:<uuid>', or 'cf:any'")
    end

    class Relationships < BaseMessage
      register_allowed_keys [:route]

      validates_with NoAdditionalKeysValidator
      validates :route, presence: true, to_one_relationship: true

      def route_guid
        HashUtils.dig(route, :data, :guid)
      end
    end
  end
end
