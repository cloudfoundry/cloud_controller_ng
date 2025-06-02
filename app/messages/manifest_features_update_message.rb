require 'messages/base_message'

module VCAP::CloudController
  class ManifestFeaturesUpdateMessage < BaseMessage
    register_allowed_keys [:features]

    validates_with NoAdditionalKeysValidator

    validate :features do
      errors.add(:features, 'must be a map of valid feature names to booleans (true = enabled, false = disabled)') unless is_valid(features)
    end

    private

    def is_valid(features)
      return false unless features.is_a?(Hash) && features.any?

      features.all? { |feature, enabled| valid_feature?(feature) && [true, false].include?(enabled) }
    end

    def valid_feature?(feature)
      AppFeatures.all_features.include?(feature.to_s)
    end
  end
end
