require 'messages/base_message'

module VCAP::CloudController
  class AppServiceAccountUpdateMessage < BaseMessage
    register_allowed_keys [:data]
    validates_with NoAdditionalKeysValidator
    validate :relationship_data

    def account_guid
      HashUtils.dig(data, :guid)
    end

    def relationship_data
      unless requested?(:data)
        errors.add(:data, 'must be provided')
        return
      end
      return if data.nil?
      return if data.is_a?(Hash) && data.keys == [:guid] && account_guid.is_a?(String) && account_guid.present?

      errors.add(:data, 'must be null or an object containing only a nonempty guid string')
    end
  end
end
