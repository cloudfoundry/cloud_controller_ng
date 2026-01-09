require 'messages/metadata_base_message'

module VCAP::CloudController
  class RouteOptionsMessage < BaseMessage
    # Register all possible keys upfront so attr_accessors are created
    register_allowed_keys %i[loadbalancing hash_header hash_balance]

    def self.valid_route_options
      options = %i[loadbalancing]
      options += %i[hash_header hash_balance] if VCAP::CloudController::FeatureFlag.enabled?(:hash_based_routing)
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
      return if loadbalancing.blank?
      return if self.class.valid_loadbalancing_algorithms.include?(loadbalancing)

      errors.add(:loadbalancing, "must be one of '#{self.class.valid_loadbalancing_algorithms.join(', ')}' if present")
    end

    def route_options_are_valid
      valid_options = self.class.valid_route_options

      # Check if any requested options are not in valid_route_options
      # Check needs to be done manually, as the set of allowed options may change during runtime (feature flag)
      invalid_keys = requested_keys.select do |key|
        value = public_send(key) if respond_to?(key)
        value.present? && valid_options.exclude?(key)
      end

      errors.add(:base, "Unknown field(s): '#{invalid_keys.join("', '")}'") if invalid_keys.any?
    end

    def hash_options_are_valid
      # Only validate hash-specific options when the feature flag is enabled
      # If disabled, route_options_are_valid will already report them as unknown fields
      return unless VCAP::CloudController::FeatureFlag.enabled?(:hash_based_routing)

      # Feature flag is enabled - validate hash-specific options

      # Validate hash_header length if present
      if hash_header.present?
        # Check length (at most 128 characters)
        if hash_header.to_s.length > 128
          errors.add(:hash_header, 'must be at most 128 characters')
          return
        end
      end

      # Validate hash_balance is numeric if present
      if hash_balance.present?
        # Check length first (at most 16 characters)
        if hash_balance.to_s.length > 16
          errors.add(:hash_balance, 'must be at most 16 characters')
          return
        end

        begin
          balance_float = Float(hash_balance)
          # Must be either 0 or >= 1.1 and <= 10.0
          unless balance_float == 0 || (balance_float >= 1.1 && balance_float <= 10)
            errors.add(:hash_balance, 'must be either 0 or between 1.1 and 10.0')
          end
        rescue ArgumentError, TypeError
          errors.add(:hash_balance, 'must be a numeric value')
        end
      end

      # When loadbalancing is explicitly set to non-hash value, hash options are not allowed
      errors.add(:base, 'Hash header can only be set when loadbalancing is hash') if hash_header.present? && loadbalancing.present? && loadbalancing != 'hash'
      errors.add(:base, 'Hash balance can only be set when loadbalancing is hash') if hash_balance.present? && loadbalancing.present? && loadbalancing != 'hash'
    end
  end
end
