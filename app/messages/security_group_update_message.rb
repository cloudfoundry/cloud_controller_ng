require 'messages/base_message'

module VCAP::CloudController
  class SecurityGroupUpdateMessage < BaseMessage
    MAX_SECURITY_GROUP_NAME_LENGTH = 250

    def self.key_requested?(key)
      proc { |a| a.requested?(key) }
    end

    register_allowed_keys [:name, :globally_enabled, :rules]

    validates_with NoAdditionalKeysValidator
    validates_with RulesValidator, if: key_requested?(:rules)

    validate :validate_globally_enabled, if: key_requested?(:globally_enabled)

    validates :name,
      string: true,
      length: { minimum: 1, maximum: MAX_SECURITY_GROUP_NAME_LENGTH },
      if: key_requested?(:name)

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
  end
end
