require 'messages/metadata_base_message'
require 'messages/validators/url_validator'
require 'messages/validators/authentication_validator'
require 'messages/basic_credentials_message'
require 'messages/authentication_message'
require 'messages/mixins/authentication_message_mixin'
require 'utils/hash_utils'

module VCAP::CloudController
  class ServiceBrokerUpdateMessage < MetadataBaseMessage
    include AuthenticationMessageMixin

    register_allowed_keys [:name, :url, :authentication]

    validates :name, string: true, allow_nil: true
    validate :validate_name

    validates :url, string: true, allow_nil: true
    validates_with UrlValidator, if: :url

    validates :authentication, hash: true, allow_nil: true
    validates_with AuthenticationValidator, if: ->(record) { record.authentication.is_a? Hash }
    validates_with NoAdditionalKeysValidator

    def validate_name
      if name == ''
        errors.add(:name, 'must not be empty string')
      end
    end
  end

  class ServiceBrokerUpdateMetadataMessage < MetadataBaseMessage
    register_allowed_keys []
  end
end
