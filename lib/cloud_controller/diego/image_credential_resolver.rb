require 'utils/uri_utils'

module VCAP::CloudController
  module Diego
    module ImageCredentialResolver
      Credentials = Struct.new(:username, :password, keyword_init: true)
      private_constant :Credentials

      module_function

      def resolve(primary_username:, primary_password:, lifecycle_data:)
        return credentials(primary_username, primary_password) if primary_username.present? && primary_password.present?
        return credentials(primary_username, primary_password) unless lifecycle_data.respond_to?(:stack) && custom_stack?(lifecycle_data.stack)

        resolve_from_custom_stack(lifecycle_data)
      end

      def resolve_for_staging(primary_username:, primary_password:, lifecycle:)
        return credentials(primary_username, primary_password) if primary_username.present? && primary_password.present?
        return credentials(nil, nil) unless lifecycle.respond_to?(:credentials_for_staging) && lifecycle.respond_to?(:staging_stack)
        return credentials(primary_username, primary_password) unless custom_stack?(lifecycle.staging_stack)

        stack_host = UriUtils.custom_stack_registry_host(lifecycle.staging_stack)
        return credentials(nil, nil) unless stack_host

        extract_credentials(lifecycle.credentials_for_staging, stack_host)
      end

      def resolve_from_custom_stack(lifecycle_data)
        return credentials(nil, nil) unless lifecycle_data.respond_to?(:credentials) && lifecycle_data.respond_to?(:stack)

        stack_host = UriUtils.custom_stack_registry_host(lifecycle_data.stack)
        return credentials(nil, nil) unless stack_host

        extract_credentials(lifecycle_data.credentials, stack_host)
      end
      private_class_method :resolve_from_custom_stack

      def custom_stack?(stack)
        UriUtils.is_custom_stack_uri?(stack)
      end
      private_class_method :custom_stack?

      def extract_credentials(credentials_by_host, host)
        return credentials(nil, nil) unless credentials_by_host.is_a?(Hash)

        credentials_by_host = credentials_by_host.deep_stringify_keys
        creds = credentials_by_host[host]
        return credentials(nil, nil) unless creds.is_a?(Hash)

        username = creds['username']
        password = creds['password']
        return credentials(nil, nil) unless username.present? && password.present?

        credentials(username, password)
      end
      private_class_method :extract_credentials

      def credentials(username, password)
        Credentials.new(username:, password:)
      end
      private_class_method :credentials
    end
  end
end
