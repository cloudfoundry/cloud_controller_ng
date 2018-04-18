require 'messages/base_message'

module VCAP::CloudController
  class IsolationSegmentUpdateMessage < BaseMessage
    register_allowed_keys [:name]

    validates_with NoAdditionalKeysValidator
    validates :name, string: true
  end
end
