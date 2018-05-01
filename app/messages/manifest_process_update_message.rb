require 'messages/base_message'

module VCAP::CloudController
  class ManifestProcessUpdateMessage < BaseMessage
    register_allowed_keys [:command, :health_check_type, :health_check_http_endpoint, :timeout, :type]

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
      inclusion: { in: %w(port process http), message: 'must be "port", "process", or "http"' },
      if: proc { |a| a.requested?(:health_check_type) }

    validates :health_check_http_endpoint,
      allow_nil: true,
      uri_path: true,
      if: proc { |a| a.requested?(:health_check_http_endpoint) }

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
