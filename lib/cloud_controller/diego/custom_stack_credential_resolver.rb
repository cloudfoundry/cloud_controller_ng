require 'utils/uri_utils'

module VCAP::CloudController
  module Diego
    module CustomStackCredentialResolver
      module_function

      def resolve(stack_uri:, credentials_by_host:)
        registry_host = UriUtils.custom_stack_registry_host(stack_uri)
        return { image_username: nil, image_password: nil } unless registry_host && credentials_by_host.is_a?(Hash)

        registry_entry = credentials_by_host.deep_stringify_keys[registry_host]
        return { image_username: nil, image_password: nil } unless registry_entry.is_a?(Hash)

        username = registry_entry['username']
        password = registry_entry['password']
        return { image_username: nil, image_password: nil } unless username.present? && password.present?

        { image_username: username, image_password: password }
      end
    end
  end
end
