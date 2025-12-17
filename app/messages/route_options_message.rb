require 'messages/metadata_base_message'

module VCAP::CloudController
  class RouteOptionsMessage < BaseMessage
    # Register all possible keys upfront so attr_accessors are created
    register_allowed_keys %i[loadbalancing hash_header hash_balance]

    def self.valid_route_options
      options = %i[loadbalancing]
      if VCAP::CloudController::FeatureFlag.enabled?(:hash_based_routing)
        options += %i[hash_header hash_balance]
      end
      options.freeze
    end

    def self.valid_loadbalancing_algorithms
      algorithms = %w[round-robin least-connection]
      algorithms << 'hash' if VCAP::CloudController::FeatureFlag.enabled?(:hash_based_routing)
      algorithms.freeze
    end

    validates_with NoAdditionalKeysValidator
    validate :loadbalancing_algorithm_is_valid
    validate :route_options_are_valid
    validate :hash_options_are_valid

    def loadbalancing_algorithm_is_valid
      return if loadbalancing.nil?
      return if self.class.valid_loadbalancing_algorithms.include?(loadbalancing)

      errors.add(:loadbalancing, "must be one of '#{self.class.valid_loadbalancing_algorithms.join(', ')}' if present")
    end

    def route_options_are_valid
      valid_options = self.class.valid_route_options

      # Check if any requested options are not in valid_route_options
      # Check needs to be done manually, as the set of allowed options may change during runtime (feature flag)
      requested_keys.each do |key|
        value = public_send(key) if respond_to?(key)
        next unless value.present?

        unless valid_options.include?(key)
          errors.add(:base, "Unknown field(s): '#{key}'")
          return
        end
      end
    end

    def hash_options_are_valid
      # Only validate hash-specific options when the feature flag is enabled
      # If disabled, route_options_are_valid will already report them as unknown fields
      return unless VCAP::CloudController::FeatureFlag.enabled?(:hash_based_routing)

      # Feature flag is enabled - validate hash-specific options
      # Validate hash_balance is numeric if present
      if hash_balance.present?
        begin
          Float(hash_balance)
        rescue ArgumentError, TypeError
          errors.add(:hash_balance, 'must be a numeric value')
        end
      end

      # When loadbalancing is explicitly set to non-hash value, hash options are not allowed
      if hash_header.present? && loadbalancing.present? && loadbalancing != 'hash'
        errors.add(:base, 'Hash header can only be set when loadbalancing is hash')
      end

      if hash_balance.present? && loadbalancing.present? && loadbalancing != 'hash'
        errors.add(:base, 'Hash balance can only be set when loadbalancing is hash')
      end
    end
  end
end
