require 'messages/validators'

module VCAP::CloudController
  class SecurityGroupCreateMessage < BaseMessage
    MAX_SECURITY_GROUP_NAME_LENGTH = 250

    register_allowed_keys [:name, :globally_enabled]

    validates_with NoAdditionalKeysValidator

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

    private

    def validate_globally_enabled
      return if globally_enabled.nil?

      if !globally_enabled.is_a? Hash
        errors.add(:globally_enabled, 'must be a hash')
      elsif (globally_enabled.keys - [:running, :staging]).any?
        errors.add(:globally_enabled, "only allows keys 'running' or 'boolean'")
      elsif globally_enabled.values.any? { |value| [true, false].exclude? value }
        errors.add(:globally_enabled, 'values must be booleans')
      end
    end
  end
end
