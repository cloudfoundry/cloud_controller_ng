require 'uri'

module VCAP::CloudController
  class BuildpackLifecycleDataMessage < BaseMessage
    register_allowed_keys %i[buildpacks stack credentials]

    validates_with NoAdditionalKeysValidator

    validates :stack,
              string: true,
              allow_nil: true,
              length: { in: 1..4096, message: 'must be between 1 and 4096 characters' }

    validates :buildpacks,
              array: true,
              allow_nil: true

    validates :credentials,
              hash: true,
              allow_nil: true

    validate :buildpacks_content
    validate :credentials_content
    validate :custom_stack_requires_custom_buildpack

    def buildpacks_content
      return unless buildpacks.is_a?(Array)

      non_string = length_error = false

      buildpacks.each do |buildpack|
        unless buildpack.is_a?(String)
          non_string = true
          next
        end
        length_error = true if buildpack.blank? || buildpack.length > 4096
      end

      errors.add(:buildpacks, 'can only contain strings') if non_string
      errors.add(:buildpacks, 'entries must be between 1 and 4096 characters') if length_error
    end

    def credentials_content
      return unless credentials.is_a?(Hash)

      credentials.each do |registry, creds|
        unless creds.is_a?(Hash)
          errors.add(:credentials, "for registry '#{registry}' must be a hash")
          next
        end

        has_username = creds.key?('username') || creds.key?(:username)
        has_password = creds.key?('password') || creds.key?(:password)
        errors.add(:base, "credentials for #{registry} must include 'username' and 'password'") unless has_username && has_password
      end
    end

    def custom_stack_requires_custom_buildpack
      return unless stack.is_a?(String) && is_custom_stack?(stack)
      return unless FeatureFlag.enabled?(:diego_custom_stacks)
      return unless buildpacks.is_a?(Array)

      buildpacks.each do |buildpack_name|
        # If buildpack is a URL, it's custom
        next if buildpack_name&.match?(URI::DEFAULT_PARSER.make_regexp)

        # Check if it's a system buildpack
        system_buildpack = Buildpack.find(name: buildpack_name)
        if system_buildpack
          errors.add(:base, 'Buildpack must be a custom buildpack when using a custom stack')
          break
        end
      end
    end

    private

    def is_custom_stack?(stack_name)
      # Check for various container registry URL formats
      return true if stack_name.include?('docker://')
      return true if stack_name.match?(%r{^https?://})  # Any https/http URL
      return true if stack_name.include?('.')  # Any string with a dot (likely a registry)
      false
    end
  end
end
