module VCAP::CloudController
  class FeatureFlag < Sequel::Model
    FF_ERROR_MESSAGE_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/.freeze

    class UndefinedFeatureFlagError < StandardError
    end

    DEFAULT_FLAGS = {
      user_org_creation: false,
      private_domain_creation: true,
      app_bits_upload: true,
      app_scaling: true,
      route_creation: true,
      service_instance_creation: true,
      diego_docker: false,
      set_roles_by_username: true,
      unset_roles_by_username: true,
    }.freeze

    export_attributes :name, :enabled, :error_message
    import_attributes :name, :enabled, :error_message

    def validate
      validates_presence :name
      validates_unique :name
      validates_presence :enabled

      validates_includes DEFAULT_FLAGS.keys.map(&:to_s), :name
      validates_format FF_ERROR_MESSAGE_REGEX, :error_message if error_message
    end

    def self.enabled?(feature_flag_name)
      feature_flag = FeatureFlag.find(name: feature_flag_name)
      return feature_flag.enabled if feature_flag
      DEFAULT_FLAGS.fetch(feature_flag_name.to_sym)

    rescue KeyError
      raise UndefinedFeatureFlagError.new "invalid key: #{feature_flag_name}"
    end

    def self.disabled?(feature_flag_name)
      !FeatureFlag.enabled?(feature_flag_name)
    end

    def self.raise_unless_enabled!(feature_flag_name)
      feature_flag = FeatureFlag.find(name: feature_flag_name)

      err_message = feature_flag_name

      if feature_flag && feature_flag.error_message
        err_message = feature_flag.error_message
      end

      raise VCAP::Errors::ApiError.new_from_details('FeatureDisabled', err_message) if !enabled?(feature_flag_name)
    rescue KeyError
      raise UndefinedFeatureFlagError.new "invalid key: #{feature_flag_name}"
    end
  end
end
