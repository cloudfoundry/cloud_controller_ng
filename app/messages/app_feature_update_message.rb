require 'messages/base_message'

module VCAP::CloudController
  class AppFeatureUpdateMessage < BaseMessage
    register_allowed_keys [:enabled]

    validates_with NoAdditionalKeysValidator
    validates :enabled, boolean: true

    def self.create_from_http_request(body)
      AppFeatureUpdateMessage.new(body.deep_symbolize_keys)
    end
  end
end
