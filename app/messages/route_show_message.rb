require 'messages/base_message'

module VCAP::CloudController
  class RouteShowMessage < BaseMessage
    register_allowed_keys [:guid]

    validates_with NoAdditionalParamsValidator

    validates :guid, presence: true, string: true
  end
end
