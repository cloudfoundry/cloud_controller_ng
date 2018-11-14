require 'messages/base_message'

module VCAP::CloudController
  class SpaceUpdateIsolationSegmentMessage < BaseMessage
    register_allowed_keys [:data]

    def self.data_requested?
      @data_requested ||= proc { |a| a.requested?(:data) }
    end

    validates_with NoAdditionalKeysValidator
    validates :data, presence: true, hash: true, allow_nil: true
    validate :data_content, if: data_requested?

    def isolation_segment_guid
      HashUtils.dig(data, :guid)
    end

    def data_content
      return if data.nil?

      errors.add(:data, 'can only accept one key') unless data.keys.length == 1
      errors.add(:data, "can only accept key 'guid'") unless data.key?(:guid)
      errors.add(:data, "#{isolation_segment_guid} must be a string") if isolation_segment_guid && !isolation_segment_guid.is_a?(String)
    end
  end
end
