require 'messages/metadata_base_message'

module VCAP::CloudController
  class RouteOptionsMessage < BaseMessage
    # Register all possible keys upfront so attr_accessors are created
    register_allowed_keys %i[loadbalancing hash_header hash_balance allowed_sources]

    def self.valid_route_options
      options = %i[loadbalancing]
      options += %i[hash_header hash_balance] if VCAP::CloudController::FeatureFlag.enabled?(:hash_based_routing)
      options += %i[allowed_sources] if VCAP::CloudController::FeatureFlag.enabled?(:app_to_app_mtls_routing)
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
    validate :allowed_sources_options_are_valid

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

      validate_hash_header_length
      validate_hash_balance_value
      validate_hash_options_with_loadbalancing
    end

    def validate_hash_header_length
      return unless hash_header.present? && (hash_header.to_s.length > 128)

      errors.add(:hash_header, 'must be at most 128 characters')
    end

    def validate_hash_balance_value
      return if hash_balance.blank?

      if hash_balance.to_s.length > 16
        errors.add(:hash_balance, 'must be at most 16 characters')
        return
      end

      validate_hash_balance_numeric
    end

    def validate_hash_balance_numeric
      balance_float = Float(hash_balance)
      # Must be either 0 or >= 1.1 and <= 10.0
      errors.add(:hash_balance, 'must be either 0 or between 1.1 and 10.0') unless balance_float == 0 || balance_float.between?(1.1, 10)
    rescue ArgumentError, TypeError
      errors.add(:hash_balance, 'must be a numeric value')
    end

    def validate_hash_options_with_loadbalancing
      # When loadbalancing is explicitly set to non-hash value, hash options are not allowed
      errors.add(:base, 'Hash header can only be set when loadbalancing is hash') if hash_header.present? && loadbalancing.present? && loadbalancing != 'hash'
      errors.add(:base, 'Hash balance can only be set when loadbalancing is hash') if hash_balance.present? && loadbalancing.present? && loadbalancing != 'hash'
    end

    def allowed_sources_options_are_valid
      # Only validate allowed_sources when the feature flag is enabled
      # If disabled, route_options_are_valid will already report it as unknown field
      return unless VCAP::CloudController::FeatureFlag.enabled?(:app_to_app_mtls_routing)
      return if allowed_sources.blank?

      validate_allowed_sources_structure
      validate_allowed_sources_any_exclusivity
      validate_allowed_sources_guids_exist
    end

    private

    # Normalize allowed_sources to use string keys (Rails may parse JSON with symbol keys)
    def normalized_allowed_sources
      @normalized_allowed_sources ||= allowed_sources.is_a?(Hash) ? allowed_sources.transform_keys(&:to_s) : allowed_sources
    end

    def validate_allowed_sources_structure
      unless allowed_sources.is_a?(Hash)
        errors.add(:allowed_sources, 'must be an object')
        return
      end

      valid_keys = %w[apps spaces orgs any]
      invalid_keys = normalized_allowed_sources.keys - valid_keys
      errors.add(:allowed_sources, "contains invalid keys: #{invalid_keys.join(', ')}") if invalid_keys.any?

      # Validate types
      %w[apps spaces orgs].each do |key|
        next unless normalized_allowed_sources[key].present?

        unless normalized_allowed_sources[key].is_a?(Array) && normalized_allowed_sources[key].all? { |v| v.is_a?(String) }
          errors.add(:allowed_sources, "#{key} must be an array of strings")
        end
      end

      return unless normalized_allowed_sources['any'].present? && ![true, false].include?(normalized_allowed_sources['any'])

      errors.add(:allowed_sources, 'any must be a boolean')
    end

    def validate_allowed_sources_any_exclusivity
      return unless allowed_sources.is_a?(Hash)

      has_any = normalized_allowed_sources['any'] == true
      has_lists = %w[apps spaces orgs].any? { |key| normalized_allowed_sources[key].present? && normalized_allowed_sources[key].any? }

      return unless has_any && has_lists

      errors.add(:allowed_sources, 'any is mutually exclusive with apps, spaces, and orgs')
    end

    def validate_allowed_sources_guids_exist
      return unless allowed_sources.is_a?(Hash)
      return if errors[:allowed_sources].any? # Skip if already invalid

      validate_app_guids_exist
      validate_space_guids_exist
      validate_org_guids_exist
    end

    def validate_app_guids_exist
      app_guids = normalized_allowed_sources['apps']
      return if app_guids.blank?

      existing_guids = AppModel.where(guid: app_guids).select_map(:guid)
      missing_guids = app_guids - existing_guids
      return if missing_guids.empty?

      errors.add(:allowed_sources, "apps contains non-existent app GUIDs: #{missing_guids.join(', ')}")
    end

    def validate_space_guids_exist
      space_guids = normalized_allowed_sources['spaces']
      return if space_guids.blank?

      existing_guids = Space.where(guid: space_guids).select_map(:guid)
      missing_guids = space_guids - existing_guids
      return if missing_guids.empty?

      errors.add(:allowed_sources, "spaces contains non-existent space GUIDs: #{missing_guids.join(', ')}")
    end

    def validate_org_guids_exist
      org_guids = normalized_allowed_sources['orgs']
      return if org_guids.blank?

      existing_guids = Organization.where(guid: org_guids).select_map(:guid)
      missing_guids = org_guids - existing_guids
      return if missing_guids.empty?

      errors.add(:allowed_sources, "orgs contains non-existent organization GUIDs: #{missing_guids.join(', ')}")
    end
  end
end
