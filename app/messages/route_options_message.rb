require 'messages/metadata_base_message'

module VCAP::CloudController
  class RouteOptionsMessage < BaseMessage
    VALID_MANIFEST_ROUTE_OPTIONS = %i[loadbalancing hash_header hash_balance].freeze
    VALID_ROUTE_OPTIONS = %i[loadbalancing hash_header hash_balance].freeze
    VALID_LOADBALANCING_ALGORITHMS_WITH_HASH = %w[round-robin least-connection hash].freeze
    VALID_LOADBALANCING_ALGORITHMS_WITHOUT_HASH = %w[round-robin least-connection].freeze

    register_allowed_keys VALID_ROUTE_OPTIONS
    validates_with NoAdditionalKeysValidator
    validate :validate_loadbalancing_with_feature_flag

    validate :validate_hash_options, if: -> { errors[:loadbalancing].empty? }

    def self.valid_loadbalancing_algorithms
      if FeatureFlag.enabled?(:hash_based_routing)
        VALID_LOADBALANCING_ALGORITHMS_WITH_HASH
      else
        VALID_LOADBALANCING_ALGORITHMS_WITHOUT_HASH
      end
    end

    private

    def validate_loadbalancing_with_feature_flag
      return if loadbalancing.nil?

      valid_algorithms = self.class.valid_loadbalancing_algorithms
      return if valid_algorithms.include?(loadbalancing)

      errors.add(:loadbalancing, "must be one of '#{valid_algorithms.join(', ')}' if present")
    end

    def validate_hash_options
      if loadbalancing == 'hash'
        validate_hash_header_present
        validate_hash_balance_format
      else
        validate_hash_options_not_present_for_non_hash
      end
    end

    def validate_hash_header_present
      if hash_header.blank?
        errors.add(:hash_header, 'must be present when loadbalancing is set to hash')
      elsif !hash_header.is_a?(String)
        errors.add(:hash_header, 'must be a string')
      end
    end

    def validate_hash_balance_format
      return if hash_balance.nil?

      # Convert string to float if needed (from CLI input)
      begin
        hash_balance_float = Float(hash_balance)
        errors.add(:hash_balance, 'must be greater than or equal to 0.0') if hash_balance_float < 0.0
      rescue ArgumentError, TypeError
        errors.add(:hash_balance, 'must be a valid number')
      end
    end

    def validate_hash_options_not_present_for_non_hash
      errors.add(:hash_header, 'can only be set when loadbalancing is hash') if hash_header.present?
      return if hash_balance.blank?

      errors.add(:hash_balance, 'can only be set when loadbalancing is hash')
    end
  end
end
