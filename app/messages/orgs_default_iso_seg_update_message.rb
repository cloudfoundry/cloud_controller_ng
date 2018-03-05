require 'messages/base_message'

module VCAP::CloudController
  class OrgDefaultIsoSegUpdateMessage < BaseMessage
    ALLOWED_KEYS = [:data].freeze

    attr_accessor(*ALLOWED_KEYS)

    def self.create_from_http_request(body)
      OrgDefaultIsoSegUpdateMessage.new(body.deep_symbolize_keys)
    end

    def self.data_requested?
      @data_requested ||= proc { |a| a.requested?(:data) }
    end

    validates_with NoAdditionalKeysValidator
    validates :data, presence: true, hash: true, allow_nil: true
    validate :data_content, if: data_requested?

    def default_isolation_segment_guid
      HashUtils.dig(data, :guid)
    end

    def data_content
      return if data.nil?
      errors.add(:data, 'can only accept one key') unless data.keys.length == 1
      errors.add(:data, "can only accept key 'guid'") unless data.keys.include?(:guid)
      if default_isolation_segment_guid && !default_isolation_segment_guid.is_a?(String)
        errors.add(:data, "#{default_isolation_segment_guid} must be a string")
      end
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
