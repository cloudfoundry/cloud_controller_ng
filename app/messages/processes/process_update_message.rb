require 'messages/base_message'

module VCAP::CloudController
  class ProcessUpdateMessage < BaseMessage
    ALLOWED_KEYS = [:command, :health_check].freeze

    attr_accessor(*ALLOWED_KEYS)

    def self.create_from_http_request(body)
      ProcessUpdateMessage.new(body.deep_symbolize_keys)
    end

    def initialize(params={})
      super(params)
      @requested_keys << :health_check_type if HashUtils.dig(params, :health_check, :type)
      @requested_keys << :health_check_timeout if HashUtils.dig(params, :health_check, :data, :timeout)
      @requested_keys << :health_check_endpoint if HashUtils.dig(params, :health_check, :data, :endpoint)
    end

    def self.health_check_requested?
      @health_check_requested ||= proc { |a| a.requested?(:health_check) }
    end

    validates_with NoAdditionalKeysValidator

    validates :command,
    string: true,
    length: { in: 1..4096, message: 'must be between 1 and 4096 characters' },
    if:     proc { |a| a.requested?(:command) }

    validates :health_check_type,
    inclusion: { in: %w(port process http), message: 'must be "port", "process", or "http"' },
    if: health_check_requested?

    validates :health_check_timeout,
    allow_nil: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 },
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

    def health_check_endpoint
      HashUtils.dig(health_check, :data, :endpoint)
    end

    def audit_hash
      super(exclude: [:health_check_type, :health_check_timeout, :health_check_endpoint])
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
