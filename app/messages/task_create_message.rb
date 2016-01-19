require 'messages/base_message'

module VCAP::CloudController
  class TaskCreateMessage < BaseMessage
    ALLOWED_KEYS = [:name, :command]

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator

    def self.create(body)
      TaskCreateMessage.new(body.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
