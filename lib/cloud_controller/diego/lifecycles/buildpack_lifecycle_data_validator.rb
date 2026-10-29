require 'active_model'

module VCAP::CloudController
  class BuildpackLifecycleDataValidator
    include ActiveModel::Model

    attr_accessor :buildpack_infos, :stack, :stack_name, :lifecycle_type, :credentials, :credentials_from_message

    validate :buildpacks_are_uri_or_nil
    validate :custom_stack_uri_is_valid
    validate :stack_exists_in_db
    validate :custom_stack_has_auto_detect_buildpack
    validate :no_custom_stack_userinfo
    validate :no_dual_credential_sources

    def buildpacks_are_uri_or_nil
      buildpack_infos.each do |buildpack_info|
        next if buildpack_info.buildpack_record.present?
        next if buildpack_info.buildpack.nil?
        next if buildpack_info.buildpack_url

        if stack
          errors.add(:buildpack, %("#{buildpack_info.buildpack}" for stack "#{stack.name}" must be an existing admin buildpack or a valid git URI))
        else
          errors.add(:buildpack, %("#{buildpack_info.buildpack}" must be an existing admin buildpack or a valid git URI))
        end
      end
    end

    def stack_exists_in_db
      return if UriUtils.is_custom_stack_uri?(stack_name) && FeatureFlag.enabled?(:diego_custom_stacks)
      return if custom_stack_uri?(stack_name) && !UriUtils.is_custom_stack_uri?(stack_name)
      return unless stack.nil?

      message = if FeatureFlag.enabled?(:diego_custom_stacks)
                  'must be an existing stack or a valid container image URI starting with "docker://"'
                else
                  'must be an existing stack'
                end
      errors.add(:stack, message)
    end

    def custom_stack_uri_is_valid
      return if stack
      return unless custom_stack_uri?(stack_name)
      return if UriUtils.is_custom_stack_uri?(stack_name)

      errors.add(:stack, 'must be a valid container image URI starting with "docker://"')
    end

    def no_custom_stack_userinfo
      return unless UriUtils.is_custom_stack_uri?(stack_name) && UriUtils.url_has_userinfo?(stack_name)

      errors.add(:stack, 'Custom stack URIs must not contain credentials; use data.credentials instead')
    end

    def custom_stack_has_auto_detect_buildpack
      return unless UriUtils.is_custom_stack_uri?(stack_name) && buildpack_infos.empty?
      return if unpinned_admin_buildpack_exists?

      errors.add(:base, 'You must either specify a custom buildpack URL or your platform operator must provide an enabled buildpack that is not pinned to a stack')
    end

    def no_dual_credential_sources
      return unless url_has_userinfo? && credentials.present?

      if credentials_from_message
        errors.add(:base, 'Provide buildpack credentials either in the buildpack URI or in data.credentials, not both')
      else
        errors.add(:base, 'This app already has stored buildpack credentials (data.credentials); a buildpack URI with embedded credentials conflicts with them. ' \
                          'Remove the credentials from the URI, or clear the stored credentials with "credentials: null".')
      end
    end

    private

    def unpinned_admin_buildpack_exists?
      lifecycle = lifecycle_type || Config.config.get(:default_app_lifecycle)
      Buildpack.list_admin_buildpacks(nil, lifecycle).any? { |buildpack| buildpack.stack.nil? && buildpack.enabled? }
    end

    def url_has_userinfo?
      buildpack_infos.any? { |bi| bi.buildpack_url && UriUtils.url_has_userinfo?(bi.buildpack_url) }
    end

    def custom_stack_uri?(stack_name)
      stack_name.is_a?(String) && stack_name.start_with?('docker://')
    end
  end
end
