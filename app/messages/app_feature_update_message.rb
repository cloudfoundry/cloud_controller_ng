require 'messages/base_message'

module VCAP::CloudController
  class AppFeatureUpdateMessage < BaseMessage
    ALLOWED_KEYS = [:enabled].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator
    validates :enabled, boolean: true

    def self.create_from_http_request(body)
      AppFeatureUpdateMessage.new(body.deep_symbolize_keys)
    end
  end
end
