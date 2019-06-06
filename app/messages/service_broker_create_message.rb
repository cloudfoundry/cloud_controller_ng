require 'messages/base_message'
require 'utils/hash_utils'

module VCAP::CloudController
  class ServiceBrokerCreateMessage < BaseMessage
    register_allowed_keys [:name, :url, :credentials]
    ALLOWED_CREDENTIAL_TYPES = ['basic'].freeze

    validates_with NoAdditionalKeysValidator

    validates :name, string: true
    validates :url, string: true
    validates :credentials, hash: true
    validates_inclusion_of :credentials_type, in: ALLOWED_CREDENTIAL_TYPES,
      message: "credentials.type must be one of #{ALLOWED_CREDENTIAL_TYPES}"

    validate :validate_credentials_data

    def credentials_type
      HashUtils.dig(credentials, :type)
    end

    def credentials_data
      @credentials_data ||= BasicCredentialsMessage.new(HashUtils.dig(credentials, :data))
    end

    def validate_credentials_data
      unless credentials_data.valid?
        errors.add(
          :credentials_data,
          "Field(s) #{credentials_data.errors.keys.map(&:to_s)} must be valid: #{credentials_data.errors.full_messages}"
        )
      end
    end

    class BasicCredentialsMessage < BaseMessage
      register_allowed_keys [:username, :password]

      validates_with NoAdditionalKeysValidator

      validates :username, string: true
      validates :password, string: true
    end
  end
end
