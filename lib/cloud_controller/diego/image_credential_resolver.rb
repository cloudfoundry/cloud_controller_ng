require 'utils/uri_utils'

module VCAP::CloudController
  module Diego
    module ImageCredentialResolver
      module_function

      # Returns [username, password], falling back to custom stack registry credentials.
      def resolve(primary_username:, primary_password:, lifecycle_data:)
        return [primary_username, primary_password] if primary_username.present? && primary_password.present?

        resolve_from_custom_stack(lifecycle_data)
      end

      # Like resolve, but for staging where the lifecycle object provides :staging_stack.
      def resolve_for_staging(primary_username:, primary_password:, lifecycle:)
        return [primary_username, primary_password] if primary_username.present? && primary_password.present?
        return [nil, nil] unless lifecycle.respond_to?(:credentials) && lifecycle.respond_to?(:staging_stack)

        stack_host = UriUtils.custom_stack_registry_host(lifecycle.staging_stack)
        return [nil, nil] unless stack_host

        extract_credentials(lifecycle.credentials, stack_host)
      end

      def resolve_from_custom_stack(lifecycle_data)
        return [nil, nil] unless lifecycle_data.respond_to?(:credentials) && lifecycle_data.respond_to?(:stack)

        stack_host = UriUtils.custom_stack_registry_host(lifecycle_data.stack)
        return [nil, nil] unless stack_host

        extract_credentials(lifecycle_data.credentials, stack_host)
      end
      private_class_method :resolve_from_custom_stack

      def extract_credentials(credentials, host)
        return [nil, nil] unless credentials.is_a?(Hash)

        creds = credentials[host]
        return [nil, nil] unless creds.is_a?(Hash)

        [creds['username'], creds['password']]
      end
      private_class_method :extract_credentials
    end
  end
end
