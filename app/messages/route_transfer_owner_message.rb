require 'messages/base_message'

module VCAP::CloudController
  class RouteTransferOwnerMessage < BaseMessage
    register_allowed_keys [:data]

    validates_with NoAdditionalKeysValidator
    validates :data, presence: true, hash: true, allow_nil: false
    validate :data_content, if: -> { data.is_a?(Hash) }

    def space_guid
      HashUtils.dig(data, :guid)
    end

    def data_content
      return if data.nil?

      errors.add(:data, 'can only accept one key') unless data.keys.length == 1
      errors.add(:data, "can only accept key 'guid'") unless data.key?(:guid)
      if space_guid && !space_guid.is_a?(String)
        errors.add(:data, "#{space_guid} must be a string")
        return
      end
      if space_guid && space_guid.empty?
        errors.add(:data, "guid can't be blank")
      end
    end
  end
end
