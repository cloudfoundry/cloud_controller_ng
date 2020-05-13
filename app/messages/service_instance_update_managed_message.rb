require 'messages/metadata_base_message'
require 'messages/validators'

module VCAP::CloudController
  class ServiceInstanceUpdateManagedMessage < MetadataBaseMessage
    def self.relationships_requested?
      @relationships_requested ||= proc { |a| a.requested?(:relationships) }
    end

    register_allowed_keys [
      :name,
      :tags,
      :parameters,
      :relationships,
    ]

    validates_with NoAdditionalKeysValidator
    validates_with RelationshipValidator, if: relationships_requested?

    validates :name, string: true, allow_nil: true
    validates :tags, array: true, allow_blank: true
    validate :tags_must_be_strings

    validates :parameters, hash: true, allow_nil: true
    validates :relationships, hash: true, allow_nil: true

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    delegate :service_plan_guid, to: :relationships_message

    private

    def tags_must_be_strings
      if tags.present? && tags.is_a?(Array) && tags.any? { |i| !i.is_a?(String) }
        errors.add(:tags, 'must be a list of strings')
      end
    end

    class Relationships < BaseMessage
      register_allowed_keys [:service_plan]

      validates_with NoAdditionalKeysValidator

      validates :service_plan, presence: true, allow_nil: false, to_one_relationship: true

      def service_plan_guid
        HashUtils.dig(service_plan, :data, :guid)
      end
    end
  end
end
