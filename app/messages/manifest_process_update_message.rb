require 'messages/base_message'
require 'models/helpers/health_check_types'

module VCAP::CloudController
  class ManifestProcessUpdateMessage < BaseMessage
    register_allowed_keys [:command, :health_check_type, :health_check_http_endpoint, :health_check_invocation_timeout, :timeout, :type]

    def self.health_check_endpoint_and_type_requested?
      proc { |a| a.requested?(:health_check_type) && a.requested?(:health_check_http_endpoint) }
    end

    validates_with NoAdditionalKeysValidator
    validates_with HealthCheckValidator, if: health_check_endpoint_and_type_requested?

    validates :command,
      string: true,
      length: { in: 1..4096, message: 'must be between 1 and 4096 characters' },
      if:     proc { |a| a.requested?(:command) }

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

    validates :timeout,
      allow_nil: true,
      numericality: { only_integer: true, greater_than_or_equal_to: 1 },
      if: proc { |a| a.requested?(:timeout) }

    def initialize(params={})
      super(params)
      @requested_keys << :health_check_timeout if requested? :timeout
      @requested_keys << :health_check_endpoint if requested? :health_check_http_endpoint
    end

    def health_check_endpoint
      health_check_http_endpoint
    end

    def health_check_timeout
      timeout
    end
  end
end
