require 'messages/base_message'

module VCAP::CloudController
  class ProcessUpdateMessage < BaseMessage
    ALLOWED_KEYS = [:command]

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator

    validates :command,
      string: true,
      length: { in: 1..4096, message: 'must be between 1 and 4096 characters' },
      if:     proc { |a| a.requested?(:command) }

    def self.create_from_http_request(body)
      ProcessUpdateMessage.new(body.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
