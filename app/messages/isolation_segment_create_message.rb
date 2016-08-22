require 'messages/base_message'

module VCAP::CloudController
  class IsolationSegmentCreateMessage < BaseMessage
    ALLOWED_KEYS = [:name].freeze

    attr_accessor(*ALLOWED_KEYS)

    def self.create_from_http_request(body)
      IsolationSegmentCreateMessage.new(body.symbolize_keys)
    end

    validates_with NoAdditionalKeysValidator
    validates :name, string: true

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
