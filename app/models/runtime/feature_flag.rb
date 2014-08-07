module VCAP::CloudController
  class FeatureFlag < Sequel::Model

    class UndefinedFeatureFlagError < StandardError
    end

    DEFAULT_FLAGS = {
      user_org_creation: false
    }

    export_attributes :name, :enabled
    import_attributes :name, :enabled

    def validate
      validates_presence :name
      validates_unique :name
      validates_presence :enabled

      validates_includes DEFAULT_FLAGS.keys.map(&:to_s), :name
    end

    def self.enabled?(feature_flag_name)
      feature_flag = FeatureFlag.find(name: feature_flag_name)
      return feature_flag.enabled if feature_flag
      DEFAULT_FLAGS.fetch(feature_flag_name.to_sym)

    rescue KeyError
      raise UndefinedFeatureFlagError.new "invalid key: #{feature_flag_name}"
    end

    def self.raise_unless_enabled!(feature_flag_name, message)
      error_message = message
      if Config.config[:feature_disabled_message]
        error_message = "#{error_message}: #{Config.config[:feature_disabled_message]}"
      end

      raise VCAP::Errors::ApiError.new_from_details('FeatureDisabled', error_message) if !enabled?(feature_flag_name)
    end
  end
end
