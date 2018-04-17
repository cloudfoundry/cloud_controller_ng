require 'messages/base_message'

module VCAP::CloudController
  class ManifestServiceBindingCreateMessage < BaseMessage
    ALLOWED_KEYS = [:services].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator

    validate :services do
      errors.add(:services, 'must be a list of service instance names') unless services.is_a?(Array) && services.all? { |service| service.is_a?(String) }
    end

    def self.create_from_http_request(body)
      ManifestServiceBindingCreateMessage.new(body.deep_symbolize_keys)
    end
  end
end
