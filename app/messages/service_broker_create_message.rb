require 'messages/metadata_base_message'
require 'messages/basic_credentials_message'
require 'messages/authentication_message'
require 'messages/validators/url_validator'
require 'messages/validators/authentication_validator'
require 'messages/mixins/authentication_message_mixin'
require 'utils/hash_utils'

module VCAP::CloudController
  class ServiceBrokerCreateMessage < MetadataBaseMessage
    include AuthenticationMessageMixin
    register_allowed_keys [:name, :url, :authentication, :relationships]

    def self.relationships_requested?
      @relationships_requested ||= proc { |a| a.requested?(:relationships) }
    end

    validates :name, string: true
    validate :validate_name

    validates :url, string: true
    validates_with UrlValidator

    validates :authentication, hash: true
    validates_with AuthenticationValidator, if: ->(record) { record.authentication.is_a? Hash }

    validates_with RelationshipValidator, if: relationships_requested?
    validates_with NoAdditionalKeysValidator

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    def validate_name
      if name == ''
        errors.add(:name, 'must not be empty string')
      end
    end

    delegate :space_guid, to: :relationships_message

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
