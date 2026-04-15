require 'messages/metadata_base_message'

module VCAP::CloudController
  class AccessRuleCreateMessage < MetadataBaseMessage
    SELECTOR_REGEX = /\A(cf:(app|space|org):[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|cf:any)\z/

    register_allowed_keys %i[
      selector
      relationships
    ]

    validates_with NoAdditionalKeysValidator
    validates_with RelationshipValidator

    validates :selector, presence: true, string: true

    validate :selector_format_valid
    validate :selector_not_cf_any_with_others

    delegate :route_guid, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    private

    def selector_format_valid
      return unless selector.is_a?(String)
      return if SELECTOR_REGEX.match?(selector)

      errors.add(:selector, "must be in format 'cf:app:<uuid>', 'cf:space:<uuid>', 'cf:org:<uuid>', or 'cf:any'")
    end

    def selector_not_cf_any_with_others
      # enforced at the controller level when checking existing rules on the route
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
