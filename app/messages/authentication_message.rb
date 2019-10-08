require 'messages/base_message'

module VCAP::CloudController
  class AuthenticationMessage < BaseMessage
    register_allowed_keys [:type, :credentials]
    ALLOWED_AUTHENTICATION_TYPES = ['basic'].freeze

    validates_inclusion_of :type, in: ALLOWED_AUTHENTICATION_TYPES,
      message: "authentication.type must be one of #{ALLOWED_AUTHENTICATION_TYPES}"

    validates :credentials, hash: true

    validates_with NoAdditionalKeysValidator
  end
end
