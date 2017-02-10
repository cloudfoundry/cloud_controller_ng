require 'messages/base_message'

module VCAP::CloudController
  class SpaceUpdateMessage < BaseMessage
    ALLOWED_KEYS = [:data].freeze

    attr_accessor(*ALLOWED_KEYS)
    attr_reader :space

    def self.create_from_http_request(body)
      SpaceUpdateMessage.new(body.symbolize_keys)
    end

    validates :data, hash: true, allow_nil: true
    validates_with SpaceUpdateValidator

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
