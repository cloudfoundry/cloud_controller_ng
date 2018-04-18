require 'messages/base_message'

module VCAP::CloudController
  class IsolationSegmentUpdateMessage < BaseMessage
    register_allowed_keys [:name]

    def self.create_from_http_request(body)
      IsolationSegmentUpdateMessage.new(body.deep_symbolize_keys)
    end

    validates_with NoAdditionalKeysValidator
    validates :name, string: true
  end
end
