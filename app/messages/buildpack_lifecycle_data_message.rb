module VCAP::CloudController
  class BuildpackLifecycleDataMessage < BaseMessage
    register_allowed_keys %i[buildpacks stack stack_id credentials]

    validates_with NoAdditionalKeysValidator

    validates :stack,
              string: true,
              allow_nil: true,
              length: { in: 1..4096, message: 'must be between 1 and 4096 characters' }

    validates :stack_id,
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
    validate :stack_credentials_not_in_uri

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

      stack_host = UriUtils.custom_stack_registry_host(stack)

      credentials.each do |registry, creds|
        unless creds.is_a?(Hash)
          errors.add(:credentials, "for registry '#{registry}' must be a hash")
          next
        end

        # The stack image is pulled by Diego, which only supports username/password (HTTP Basic auth).
        # A token cannot be used to pull the stack, so reject it here rather than fail silently at staging.
        # Tokens keyed to any other registry are left alone: they are consumed by the CNB builder for
        # buildpack images (via CNB_REGISTRY_CREDS), not by the stack pull. See RFC-0046.
        next unless stack_host && registry.to_s == stack_host

        errors.add(:credentials, "for registry '#{registry}' must include 'username' and 'password'") unless username_password?(creds)
      end
    end

    def username_password?(creds)
      c = creds.transform_keys(&:to_s)
      c['username'].present? && c['password'].present?
    end

    def stack_credentials_not_in_uri
      return unless UriUtils.is_custom_stack_uri?(stack)

      host = UriUtils.custom_stack_registry_host(stack)
      errors.add(:stack, 'must not include credentials in the URI') if host&.include?('@')
    end
  end
end
