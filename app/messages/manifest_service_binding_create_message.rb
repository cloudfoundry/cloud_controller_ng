require 'messages/base_message'

module VCAP::CloudController
  class ManifestServiceBindingCreateMessage < BaseMessage
    register_allowed_keys [:services]

    validates_with NoAdditionalKeysValidator

    validate :services do
      errors.add(:services, 'must be a list of service instance names') unless services.is_a?(Array) && services.all? { |service| service.is_a?(String) }
    end
  end
end
