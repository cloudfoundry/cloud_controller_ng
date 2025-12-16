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

    def self.allowed_keys
      valid_route_options
    end
    validates_with NoAdditionalKeysValidator
    validate :loadbalancing_algorithm_is_valid
    validate :hash_options_only_with_hash_loadbalancing

    def loadbalancing_algorithm_is_valid
      return if loadbalancing.nil?
      return if self.class.valid_loadbalancing_algorithms.include?(loadbalancing)

      errors.add(:loadbalancing, "must be one of '#{self.class.valid_loadbalancing_algorithms.join(', ')}' if present")
    end

    def hash_options_only_with_hash_loadbalancing
      # When feature flag is disabled, these options are not allowed at all
      feature_enabled = VCAP::CloudController::FeatureFlag.enabled?(:hash_based_routing)

      if hash_header.present? && !feature_enabled
        errors.add(:base, 'Hash header can only be set when loadbalancing is hash')
        return
      end

      if hash_balance.present? && !feature_enabled
        errors.add(:base, 'Hash balance can only be set when loadbalancing is hash')
        return
      end

      if hash_header.present? && loadbalancing.present? && loadbalancing != 'hash'
        errors.add(:base, 'Hash header can only be set when loadbalancing is hash')
      end

      if hash_balance.present? && loadbalancing.present? && loadbalancing != 'hash'
        errors.add(:base, 'Hash balance can only be set when loadbalancing is hash')
      end
    end
  end
end
