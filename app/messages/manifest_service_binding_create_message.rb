require 'messages/base_message'

module VCAP::CloudController
  class ManifestServiceBindingCreateMessage < BaseMessage
    register_allowed_keys [:services]

    validates_with NoAdditionalKeysValidator

    validate :services do
      errors.add(:services, 'must be a list of service instances') unless is_valid(services)
    end

    def manifest_service_bindings
      return [] unless services.is_a?(Array)

      services.map do |service|
        if service.is_a?(String)
          ManifestServiceBinding.new(name: service)
        else
          ManifestServiceBinding.new(name: service[:name], parameters: service[:parameters])
        end
      end
    end

    private

    def is_valid(services)
      return false unless services.is_a?(Array)

      services.all? { |service| service.is_a?(String) || has_valid_hash_keys(service) }
    end

    def has_valid_hash_keys(service)
      valid_service_binding_keys = [:name, :parameters]
      return false unless service.is_a?(Hash)
      return false unless service.length <= valid_service_binding_keys.length && service.keys.all? { |key| valid_service_binding_keys.include?(key) }
      return false unless service.key?(:name)

      has_valid_optional_parameters(service)
    end

    def has_valid_optional_parameters(service)
      return true unless service.key?(:parameters)
      return false unless service[:parameters].is_a?(Hash)

      true
    end
  end

  class ManifestServiceBinding
    attr_accessor :name, :parameters

    def initialize(name:, parameters: {})
      @name = name
      @parameters = parameters
    end
  end
end
