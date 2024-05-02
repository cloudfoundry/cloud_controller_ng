module VCAP::CloudController
  class FeatureFlag < Sequel::Model
    FF_ERROR_MESSAGE_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/

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
      diego_cnb: false,
      set_roles_by_username: true,
      unset_roles_by_username: true,
      task_creation: true,
      env_var_visibility: true,
      space_scoped_private_broker_creation: true,
      space_developer_env_var_visibility: true,
      service_instance_sharing: false,
      hide_marketplace_from_unauthenticated_users: false,
      resource_matching: true,
      route_sharing: false
    }.freeze

    ADMIN_SKIPPABLE = %i[
      app_bits_upload
      app_scaling
      set_roles_by_username
      space_developer_env_var_visibility
      task_creation
      unset_roles_by_username
    ].freeze

    ADMIN_READ_ONLY_SKIPPABLE = [:space_developer_env_var_visibility].freeze

    export_attributes :name, :enabled, :error_message
    import_attributes :name, :enabled, :error_message

    def validate
      validates_presence :name
      validates_unique :name
      validates_presence :enabled

      validates_includes DEFAULT_FLAGS.keys.map(&:to_s), :name
      validates_format FF_ERROR_MESSAGE_REGEX, :error_message if error_message
    end

    def self.enabled?(feature_flag_name, raise_unless_enabled: false)
      return true if ADMIN_SKIPPABLE.include?(feature_flag_name) && admin?
      return true if ADMIN_READ_ONLY_SKIPPABLE.include?(feature_flag_name) && admin_read_only?

      feature_flag = FeatureFlag.find(name: feature_flag_name.to_s)
      enabled = if feature_flag
                  feature_flag.enabled
                else
                  DEFAULT_FLAGS.fetch(feature_flag_name)
                end

      if raise_unless_enabled && !enabled
        err_message = feature_flag&.error_message ? feature_flag.error_message : feature_flag_name
        raise CloudController::Errors::ApiError.new_from_details('FeatureDisabled', err_message)
      end

      enabled
    rescue KeyError
      raise UndefinedFeatureFlagError.new "invalid key: #{feature_flag_name}"
    end

    def self.disabled?(feature_flag_name)
      !enabled?(feature_flag_name)
    end

    def self.raise_unless_enabled!(feature_flag_name)
      enabled?(feature_flag_name, raise_unless_enabled: true)
    end

    def self.admin?
      VCAP::CloudController::SecurityContext.admin?
    end

    def self.admin_read_only?
      VCAP::CloudController::SecurityContext.admin_read_only?
    end

    private_class_method :admin?
  end
end
