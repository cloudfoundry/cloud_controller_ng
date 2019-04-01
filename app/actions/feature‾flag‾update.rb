module VCAP::CloudController
  class FeatureFlagUpdate
    class Error < ::StandardError
    end

    def update(feature_flag, message)
      FeatureFlag.db.transaction do
        feature_flag.error_message = message.custom_error_message if message.requested?(:custom_error_message)
        feature_flag.enabled = message.enabled if message.requested?(:enabled)
        feature_flag.save
      end
      feature_flag
    end
  end
end
