require 'messages/base_message'
module VCAP::CloudController
  class BasicCredentialsMessage < BaseMessage
    register_allowed_keys [:username, :password]

    validates_with NoAdditionalKeysValidator

    validates :username, string: true, presence: true
    validates :password, string: true, presence: true
  end
end
