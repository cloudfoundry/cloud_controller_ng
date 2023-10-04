require 'messages/metadata_base_message'
require 'models/helpers/health_check_types'

module VCAP::CloudController
  class ProcessUpdateMessage < MetadataBaseMessage
    register_allowed_keys %i[command health_check readiness_health_check]

    # rubocop:disable Metrics/CyclomaticComplexity
    def initialize(params={})
      super(params)
      params = params.deep_symbolize_keys
      @requested_keys << :health_check_type if HashUtils.dig(params, :health_check)&.key?(:type)
      @requested_keys << :health_check_timeout if HashUtils.dig(params, :health_check, :data)&.key?(:timeout)
      @requested_keys << :health_check_invocation_timeout if HashUtils.dig(params, :health_check, :data)&.key?(:invocation_timeout)
      @requested_keys << :health_check_interval if HashUtils.dig(params, :health_check, :data)&.key?(:interval)
      @requested_keys << :health_check_endpoint if HashUtils.dig(params, :health_check, :data)&.key?(:endpoint)
      @requested_keys << :readiness_health_check_type if HashUtils.dig(params, :readiness_health_check)&.key?(:type)
      @requested_keys << :readiness_health_check_invocation_timeout if HashUtils.dig(params, :readiness_health_check, :data)&.key?(:invocation_timeout)
      @requested_keys << :readiness_health_check_interval if HashUtils.dig(params, :readiness_health_check, :data)&.key?(:interval)
      @requested_keys << :readiness_health_check_endpoint if HashUtils.dig(params, :readiness_health_check, :data)&.key?(:endpoint)
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def self.command_requested?
      @command_requested ||= proc { |a| a.requested?(:command) }
    end

    validates_with NoAdditionalKeysValidator

    validates :command,
              string: true,
              length: { in: 1..4096, message: 'must be between 1 and 4096 characters' },
              allow_nil: true,
              if: command_requested?

    validates :health_check_type,
              inclusion: {
                in: [HealthCheckTypes::PORT, HealthCheckTypes::PROCESS, HealthCheckTypes::HTTP],
                message: 'must be "port", "process", or "http"'
              },
              if: -> { health_check && health_check.key?(:type) }

    validates :health_check_timeout,
              allow_nil: true,
              numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_DB_INT }

    validates :health_check_invocation_timeout,
              allow_nil: true,
              numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_DB_INT }

    validates :health_check_interval,
              allow_nil: true,
              numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_DB_INT }

    validates :health_check_endpoint,
              length: { maximum: 255 },
              allow_nil: true,
              uri_path: true

    validates :readiness_health_check_type,
              inclusion: {
                in: [HealthCheckTypes::PORT, HealthCheckTypes::PROCESS, HealthCheckTypes::HTTP],
                message: 'must be "port", "process", or "http"'
              },
              if: -> { readiness_health_check && readiness_health_check.key?(:type) }

    validates :readiness_health_check_invocation_timeout,
              allow_nil: true,
              numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_DB_INT }

    validates :readiness_health_check_interval,
              allow_nil: true,
              numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_DB_INT }

    validates :readiness_health_check_endpoint,
              length: { maximum: 255 },
              allow_nil: true,
              uri_path: true

    def health_check_type
      HashUtils.dig(health_check, :type)
    end

    def health_check_timeout
      HashUtils.dig(health_check, :data, :timeout)
    end

    def health_check_invocation_timeout
      HashUtils.dig(health_check, :data, :invocation_timeout)
    end

    def health_check_interval
      HashUtils.dig(health_check, :data, :interval)
    end

    def health_check_endpoint
      HashUtils.dig(health_check, :data, :endpoint)
    end

    def readiness_health_check_type
      HashUtils.dig(readiness_health_check, :type)
    end

    def readiness_health_check_invocation_timeout
      HashUtils.dig(readiness_health_check, :data, :invocation_timeout)
    end

    def readiness_health_check_interval
      HashUtils.dig(readiness_health_check, :data, :interval)
    end

    def readiness_health_check_endpoint
      HashUtils.dig(readiness_health_check, :data, :endpoint)
    end

    def audit_hash
      super(exclude: %i[
        health_check_type
        health_check_timeout
        health_check_invocation_timeout
        health_check_interval
        health_check_endpoint
        readiness_health_check_type
        readiness_health_check_invocation_timeout
        readiness_health_check_interval
        readiness_health_check_endpoint
      ])
    end
  end
end
