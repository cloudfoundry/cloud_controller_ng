require 'messages/base_message'
require 'models/helpers/health_check_types'

module VCAP::CloudController
  class ManifestProcessUpdateMessage < BaseMessage
    register_allowed_keys %i[
      command
      health_check_http_endpoint
      health_check_invocation_timeout
      health_check_type
      health_check_interval
      readiness_health_check_http_endpoint
      readiness_health_check_invocation_timeout
      readiness_health_check_type
      readiness_health_check_interval
      timeout
      type
    ]

    def self.health_check_endpoint_and_type_requested?
      proc { |a| a.requested?(:health_check_type) && a.requested?(:health_check_http_endpoint) }
    end

    def self.readiness_health_check_endpoint_and_type_requested?
      proc { |a| a.requested?(:readiness_health_check_type) && a.requested?(:readiness_health_check_http_endpoint) }
    end

    validates_with NoAdditionalKeysValidator
    validates_with HealthCheckValidator, if: health_check_endpoint_and_type_requested?
    validates_with ReadinessHealthCheckValidator, if: readiness_health_check_endpoint_and_type_requested?

    validates :command,
              string: true,
              length: { in: 1..4096, message: 'must be between 1 and 4096 characters' },
              if: proc { |a| a.requested?(:command) }

    validates :health_check_type,
              inclusion: {
                in: [HealthCheckTypes::PORT, HealthCheckTypes::PROCESS, HealthCheckTypes::HTTP],
                message: 'must be "port", "process", or "http"'
              },
              if: proc { |a| a.requested?(:health_check_type) }

    # This code implicitly depends on class UriPathValidator
    # See gem active_model/validations/validates.rb: validates(*attributes) for details
    validates :health_check_http_endpoint,
              allow_nil: true,
              uri_path: true,
              if: proc { |a| a.requested?(:health_check_http_endpoint) }

    validates :health_check_invocation_timeout,
              allow_nil: true,
              numericality: { only_integer: true, greater_than_or_equal_to: 1 },
              if: proc { |a| a.requested?(:health_check_invocation_timeout) }

    validates :health_check_interval,
              allow_nil: true,
              numericality: { only_integer: true, greater_than_or_equal_to: 1 },
              if: proc { |a| a.requested?(:health_check_interval) }

    validates :readiness_health_check_type,
              inclusion: {
                in: [HealthCheckTypes::PORT, HealthCheckTypes::PROCESS, HealthCheckTypes::HTTP],
                message: 'must be "port", "process", or "http"'
              },
              if: proc { |a| a.requested?(:readiness_health_check_type) }

    validates :readiness_health_check_invocation_timeout,
              allow_nil: true,
              numericality: { only_integer: true, greater_than_or_equal_to: 1 },
              if: proc { |a| a.requested?(:readiness_health_check_invocation_timeout) }

    # This code implicitly depends on class UriPathValidator
    # See gem active_model/validations/validates.rb: validates(*attributes) for details
    validates :readiness_health_check_http_endpoint,
              allow_nil: true,
              uri_path: true,
              if: proc { |a| a.requested?(:readiness_health_check_http_endpoint) }

    validates :readiness_health_check_interval,
              allow_nil: true,
              numericality: { only_integer: true, greater_than_or_equal_to: 1 },
              if: proc { |a| a.requested?(:readiness_health_check_interval) }

    validates :timeout,
              allow_nil: true,
              numericality: { only_integer: true, greater_than_or_equal_to: 1 },
              if: proc { |a| a.requested?(:timeout) }

    def initialize(params={})
      super(params)
      @requested_keys << :health_check_timeout if requested? :timeout
      @requested_keys << :health_check_endpoint if requested? :health_check_http_endpoint
      @requested_keys << :readiness_health_check_endpoint if requested? :readiness_health_check_http_endpoint
    end

    def health_check_endpoint
      health_check_http_endpoint
    end

    def health_check_timeout
      timeout
    end

    def readiness_health_check_endpoint
      readiness_health_check_http_endpoint
    end
  end
end
