require 'messages/base_message'
require 'messages/validators/security_group_rule_validator'

module VCAP::CloudController
  class SecurityGroupCreateMessage < BaseMessage
    MAX_SECURITY_GROUP_NAME_LENGTH = 250
    register_allowed_keys [:name, :globally_enabled, :relationships, :rules]

    def self.key_requested?(key)
      proc { |a| a.requested?(key) }
    end

    def self.relationships_requested?
      @relationships_requested ||= proc { |a| a.requested?(:relationships) }
    end

    validates_with NoAdditionalKeysValidator
    validates_with RelationshipValidator, if: relationships_requested?
    validates_with RulesValidator, if: key_requested?(:rules)

    validates :name,
      presence: true,
      string: true,
      length: { maximum: MAX_SECURITY_GROUP_NAME_LENGTH }

    validate :validate_globally_enabled

    def running
      HashUtils.dig(globally_enabled, :running)
    end

    def staging
      HashUtils.dig(globally_enabled, :staging)
    end

    def validate_globally_enabled
      return if globally_enabled.nil?

      if !globally_enabled.is_a? Hash
        errors.add(:globally_enabled, 'must be an object')
      elsif (globally_enabled.keys - [:running, :staging]).any?
        errors.add(:globally_enabled, "only allows keys 'running' or 'staging'")
      elsif globally_enabled.values.any? { |value| [true, false].exclude? value }
        errors.add(:globally_enabled, 'values must be booleans')
      end
    end

    # Relationships validations
    delegate :staging_space_guids, to: :relationships_message
    delegate :running_space_guids, to: :relationships_message

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    class Relationships < BaseMessage
      register_allowed_keys [:running_spaces, :staging_spaces]

      validates :running_spaces, allow_nil: true, to_many_relationship: true
      validates :staging_spaces, allow_nil: true, to_many_relationship: true

      def staging_space_guids
        staging_data = HashUtils.dig(staging_spaces, :data)
        staging_data ? staging_data.map { |space| space[:guid] } : []
      end

      def running_space_guids
        running_data = HashUtils.dig(running_spaces, :data)
        running_data ? running_data.map { |space| space[:guid] } : []
      end
    end
  end
end
