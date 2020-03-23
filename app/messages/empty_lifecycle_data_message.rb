require 'messages/base_message'

module VCAP::CloudController
  class EmptyLifecycleDataMessage < BaseMessage
    register_allowed_keys []

    validates_with NoAdditionalKeysValidator
  end
end
