require 'messages/base_message'

module VCAP::CloudController
  class TaskCreateMessage < BaseMessage
    ALLOWED_KEYS = [:name, :command, :disk_in_mb, :memory_in_mb, :droplet_guid].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator

    validates :disk_in_mb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :memory_in_mb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :droplet_guid, guid: true, allow_nil: true

    def self.create_from_http_request(body)
      TaskCreateMessage.new(body.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
