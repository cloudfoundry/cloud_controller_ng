require 'messages/base_message'

module VCAP::CloudController
  class ProcessUpdateMessage < BaseMessage
    attr_accessor :command

    validates_with NoAdditionalKeysValidator

    validates :command,
      string: true,
      length: { in: 1..4096, message: 'must be between 1 and 4096 characters' },
      if:     proc { |a| a.requested?(:command) }

    def self.create_from_http_request(body)
      ProcessUpdateMessage.new(body.symbolize_keys)
    end

    def allowed_keys
      [:command]
    end
  end
end
