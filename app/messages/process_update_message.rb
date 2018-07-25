require 'messages/base_message'
require 'models/helpers/health_check_types'

module VCAP::CloudController
  class ProcessUpdateMessage < BaseMessage
    register_allowed_keys [:command, :health_check]

    def initialize(params={})
      super(params)
      params = params.deep_symbolize_keys
      @requested_keys << :health_check_type if HashUtils.dig(params, :health_check)&.key?(:type)
      @requested_keys << :health_check_timeout if HashUtils.dig(params, :health_check, :data)&.key?(:timeout)
      @requested_keys << :health_check_invocation_timeout if HashUtils.dig(params, :health_check, :data)&.key?(:invocation_timeout)
      @requested_keys << :health_check_endpoint if HashUtils.dig(params, :health_check, :data)&.key?(:endpoint)
    end

    def self.health_check_requested?
      @health_check_requested ||= proc { |a| a.requested?(:health_check) }
    end

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
    if: health_check_requested?

    validates :health_check_timeout,
    allow_nil: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 1 },
    if: health_check_requested?

    validates :health_check_invocation_timeout,
    allow_nil: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 1 },
    if: health_check_requested?

    validates :health_check_endpoint,
    allow_nil: true,
    uri_path: true,
    if: health_check_requested?

    def health_check_type
      HashUtils.dig(health_check, :type)
    end

    def health_check_timeout
      HashUtils.dig(health_check, :data, :timeout)
    end

    def health_check_invocation_timeout
      HashUtils.dig(health_check, :data, :invocation_timeout)
    end

    def health_check_endpoint
      HashUtils.dig(health_check, :data, :endpoint)
    end

    def audit_hash
      super(exclude: [:health_check_type, :health_check_timeout, :health_check_invocation_timeout, :health_check_endpoint])
    end
  end
end
