require 'messages/base_message'

module VCAP::CloudController
  class DomainShowMessage < BaseMessage
    register_allowed_keys [:guid]

    validates_with NoAdditionalParamsValidator

    validates :guid, presence: true, string: true
  end
end
