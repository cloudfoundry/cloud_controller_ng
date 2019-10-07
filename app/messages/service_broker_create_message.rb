require 'messages/base_message'
require 'utils/hash_utils'

module VCAP::CloudController
  class ServiceBrokerCreateMessage < BaseMessage
    register_allowed_keys [:name, :url, :authentication, :relationships]
    ALLOWED_AUTHENTICATION_TYPES = ['basic'].freeze

    def self.relationships_requested?
      @relationships_requested ||= proc { |a| a.requested?(:relationships) }
    end

    validates_with NoAdditionalKeysValidator
    validates_with RelationshipValidator, if: relationships_requested?

    validates :name, string: true
    validates :url, string: true

    validates :authentication, hash: true
    validates_inclusion_of :authentication_type, in: ALLOWED_AUTHENTICATION_TYPES,
      message: "authentication.type must be one of #{ALLOWED_AUTHENTICATION_TYPES}"
    validate :validate_authentication
    validate :validate_authentication_credentials
    validate :validate_url
    validate :validate_name

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    def authentication_credentials_hash
      HashUtils.dig(authentication, :credentials)
    end

    def authentication_message
      @authentication_message ||= CredentialsMessage.new(authentication)
    end

    def authentication_credentials
      @authentication_credentials ||= BasicCredentialsMessage.new(authentication_credentials_hash)
    end

    def validate_authentication
      unless authentication_message.valid?
        errors.add(:authentication, authentication_message.errors[:base])
      end
    end

    def authentication_type
      HashUtils.dig(authentication, :type)
    end

    def validate_authentication_credentials
      unless authentication_credentials_hash.is_a?(Hash)
        errors.add(:authentication_credentials, 'must be a hash')
      end
      unless authentication_credentials.valid?
        errors.add(
          :authentication_credentials,
          "Field(s) #{authentication_credentials.errors.keys.map(&:to_s)} must be valid: #{authentication_credentials.errors.full_messages}"
        )
      end
    end

    def validate_url
      if URI::DEFAULT_PARSER.make_regexp(['https', 'http']).match?(url.to_s)
        errors.add(:url, 'must not contain authentication') if URI(url).user
      else
        errors.add(:url, 'must be a valid url')
      end
    end

    def validate_name
      if name == ''
        errors.add(:name, 'must not be empty string')
      end
    end

    delegate :space_guid, to: :relationships_message

    class CredentialsMessage < BaseMessage
      register_allowed_keys [:type, :credentials]

      validates_with NoAdditionalKeysValidator
    end

    class BasicCredentialsMessage < BaseMessage
      register_allowed_keys [:username, :password]

      validates_with NoAdditionalKeysValidator

      validates :username, string: true
      validates :password, string: true
    end

    class Relationships < BaseMessage
      register_allowed_keys [:space]

      validates_with NoAdditionalKeysValidator

      validates :space, presence: true, allow_nil: false, to_one_relationship: true

      def space_guid
        HashUtils.dig(space, :data, :guid)
      end
    end
  end
end
