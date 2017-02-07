require 'messages/base_message'

module VCAP::CloudController
  class ProcessUpdateMessage < BaseMessage
    ALLOWED_KEYS = [:command, :health_check, :ports].freeze

    attr_accessor(*ALLOWED_KEYS)

    def initialize(params={})
      super(params)
      @requested_keys << :health_check_type if params[:health_check] && params[:health_check].key?('type')
      @requested_keys << :health_check_timeout if params[:health_check] && params[:health_check]['data'] && params[:health_check]['data'].key?('timeout')
    end

    def self.health_check_requested?
      @health_check_requested ||= proc { |a| a.requested?(:health_check) }
    end

    def self.ports_requested?
      @ports_requested ||= proc { |a| a.requested?(:ports) }
    end

    validates_with NoAdditionalKeysValidator

    validates :command,
      string: true,
      length: { in: 1..4096, message: 'must be between 1 and 4096 characters' },
      if:     proc { |a| a.requested?(:command) }

    validates :health_check_type,
      inclusion: { in: %w(port process), message: 'must be "port" or "process"' },
      if: health_check_requested?

    validates :health_check_timeout,
      allow_nil: true,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 },
      if: health_check_requested?

    validate :port_validations, if: ports_requested?

    def port_validations
      unless ports.is_a?(Array)
        errors.add(:ports, 'must be an array')
        return
      end

      if ports.count > 10
        errors.add(:ports, 'may only contain up to 10 ports')
      end

      contains_non_integers = false
      contains_invalid_port = false

      ports.each do |port|
        unless port.is_a?(Integer)
          contains_non_integers = true
          next
        end
        contains_invalid_port = true if port < 1024 || port > 65535
      end

      if contains_non_integers
        errors.add(:ports, 'must be an array of integers')
      end

      if contains_invalid_port
        errors.add(:ports, 'may only contain ports between 1024 and 65535')
      end
    end

    def health_check_type
      HashUtils.dig(health_check, 'type') || HashUtils.dig(health_check, :type)
    end

    def health_check_timeout
      HashUtils.dig(health_check, 'data', 'timeout') || HashUtils.dig(health_check, :data, :timeout)
    end

    def audit_hash
      super(exclude: [:health_check_type, :health_check_timeout])
    end

    def self.create_from_http_request(body)
      ProcessUpdateMessage.new(body.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
