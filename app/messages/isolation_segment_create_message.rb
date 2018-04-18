require 'messages/base_message'

module VCAP::CloudController
  class IsolationSegmentCreateMessage < BaseMessage
    register_allowed_keys [:name]

    def self.create_from_http_request(body)
      IsolationSegmentCreateMessage.new(body.deep_symbolize_keys)
    end

    validates_with NoAdditionalKeysValidator
    validates :name, string: true
  end
end
