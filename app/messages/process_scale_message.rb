require 'messages/base_message'

module VCAP::CloudController
  class ProcessScaleMessage < BaseMessage
    attr_accessor :instances

    def allowed_keys
      [:instances]
    end

    validates_with NoAdditionalKeysValidator

    validates :instances, numericality: { only_integer: true }

    def self.create_from_http_request(body)
      ProcessScaleMessage.new(body.symbolize_keys)
    end
  end
end
