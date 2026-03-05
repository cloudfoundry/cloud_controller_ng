require 'messages/metadata_base_message'

module VCAP::CloudController
  class RouteOptionsMessage < BaseMessage
    # Register all possible keys upfront so attr_accessors are created
    # RFC-0027 compliant: only string/number/boolean values (no nested objects/arrays)
    # mtls_allowed_apps, mtls_allowed_spaces, mtls_allowed_orgs are comma-separated GUIDs
    # mtls_allow_any is a boolean
    register_allowed_keys %i[loadbalancing hash_header hash_balance mtls_allowed_apps mtls_allowed_spaces mtls_allowed_orgs mtls_allow_any]

    def self.valid_route_options
      options = %i[loadbalancing]
      options += %i[hash_header hash_balance] if VCAP::CloudController::FeatureFlag.enabled?(:hash_based_routing)
      options += %i[mtls_allowed_apps mtls_allowed_spaces mtls_allowed_orgs mtls_allow_any] if VCAP::CloudController::FeatureFlag.enabled?(:app_to_app_mtls_routing)
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
    validate :mtls_allowed_sources_options_are_valid

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

    def mtls_allowed_sources_options_are_valid
      # Only validate mtls options when the feature flag is enabled
      # If disabled, route_options_are_valid will already report them as unknown fields
      return unless VCAP::CloudController::FeatureFlag.enabled?(:app_to_app_mtls_routing)

      validate_mtls_string_types
      validate_mtls_allow_any_type
      validate_mtls_allow_any_exclusivity
      validate_mtls_guids_exist
    end

    private

    # Parse comma-separated GUIDs into an array
    def parse_guid_list(value)
      return [] if value.blank?

      value.to_s.split(',').map(&:strip).reject(&:empty?)
    end

    def validate_mtls_string_types
      # These should be strings (comma-separated GUIDs) per RFC-0027
      %i[mtls_allowed_apps mtls_allowed_spaces mtls_allowed_orgs].each do |key|
        value = public_send(key)
        next if value.blank?

        unless value.is_a?(String)
          errors.add(key, 'must be a string of comma-separated GUIDs')
        end
      end
    end

    def validate_mtls_allow_any_type
      return if mtls_allow_any.nil?

      unless [true, false, 'true', 'false'].include?(mtls_allow_any)
        errors.add(:mtls_allow_any, 'must be a boolean (true or false)')
      end
    end

    def validate_mtls_allow_any_exclusivity
      allow_any = mtls_allow_any == true || mtls_allow_any == 'true'
      has_specific = [mtls_allowed_apps, mtls_allowed_spaces, mtls_allowed_orgs].any?(&:present?)

      return unless allow_any && has_specific

      errors.add(:mtls_allow_any, 'is mutually exclusive with mtls_allowed_apps, mtls_allowed_spaces, and mtls_allowed_orgs')
    end

    def validate_mtls_guids_exist
      return if errors.any? # Skip if already invalid

      validate_app_guids_exist
      validate_space_guids_exist
      validate_org_guids_exist
    end

    def validate_app_guids_exist
      app_guids = parse_guid_list(mtls_allowed_apps)
      return if app_guids.empty?

      existing_guids = AppModel.where(guid: app_guids).select_map(:guid)
      missing_guids = app_guids - existing_guids
      return if missing_guids.empty?

      errors.add(:mtls_allowed_apps, "contains non-existent app GUIDs: #{missing_guids.join(', ')}")
    end

    def validate_space_guids_exist
      space_guids = parse_guid_list(mtls_allowed_spaces)
      return if space_guids.empty?

      existing_guids = Space.where(guid: space_guids).select_map(:guid)
      missing_guids = space_guids - existing_guids
      return if missing_guids.empty?

      errors.add(:mtls_allowed_spaces, "contains non-existent space GUIDs: #{missing_guids.join(', ')}")
    end

    def validate_org_guids_exist
      org_guids = parse_guid_list(mtls_allowed_orgs)
      return if org_guids.empty?

      existing_guids = Organization.where(guid: org_guids).select_map(:guid)
      missing_guids = org_guids - existing_guids
      return if missing_guids.empty?

      errors.add(:mtls_allowed_orgs, "contains non-existent organization GUIDs: #{missing_guids.join(', ')}")
    end
  end
end
