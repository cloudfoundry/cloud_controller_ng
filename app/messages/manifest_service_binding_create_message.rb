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
          ManifestServiceBinding.new(name: service[:name], parameters: service[:parameters], binding_name: service[:binding_name])
        end
      end
    end

    private

    def is_valid(services)
      return false unless services.is_a?(Array)

      services.all? { |service| service.is_a?(String) || has_valid_hash_keys(service) }
    end

    def has_valid_hash_keys(service)
      valid_service_binding_keys = [:name, :parameters, :binding_name]
      return false unless service.is_a?(Hash)
      return false unless service.length <= valid_service_binding_keys.length && service.keys.all? { |key| valid_service_binding_keys.include?(key) }
      return false unless service.key?(:name)

      return false unless has_valid_optional_parameters(service)
      return false unless has_valid_optional_binding_name(service)

      true
    end

    def has_valid_optional_parameters(service)
      return true unless service.key?(:parameters)
      return false unless service[:parameters].is_a?(Hash)

      true
    end

    def has_valid_optional_binding_name(service)
      return true unless service.key?(:binding_name)
      return false unless service[:binding_name].is_a?(String)

      true
    end
  end

  class ManifestServiceBinding
    attr_accessor :name, :parameters, :binding_name

    def initialize(name:, parameters: {}, binding_name: nil)
      @name = name
      @parameters = parameters
      @binding_name = binding_name
    end
  end
end
