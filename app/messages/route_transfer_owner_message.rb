require 'messages/base_message'

module VCAP::CloudController
  class RouteTransferOwnerMessage < BaseMessage
    register_allowed_keys [:guid]

    validates_with NoAdditionalKeysValidator
    validates :guid, presence: true, string: true, allow_nil: false, allow_blank: false
  end
end
