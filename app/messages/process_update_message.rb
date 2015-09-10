require 'messages/base_message'

module VCAP::CloudController
  class ProcessUpdateMessage < BaseMessage
    attr_accessor :guid, :command

    validates_with NoAdditionalKeysValidator

    validates :guid, guid: true
    validates :command,
      string: true,
      length: { in: 1..4096, message: 'must be between 1 and 4096 characters' },
      if:     proc { |a| a.requested?(:command) }

    def self.create_from_http_request(guid, body)
      ProcessUpdateMessage.new(body.symbolize_keys.merge(guid: guid))
    end

    def allowed_keys
      [:guid, :command]
    end
  end
end
