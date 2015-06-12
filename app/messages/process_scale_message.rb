require 'messages/base_message'

module VCAP::CloudController
  class ProcessScaleMessage < BaseMessage
    attr_accessor :instances, :memory_in_mb, :disk_in_mb

    def allowed_keys
      [:instances, :memory_in_mb, :disk_in_mb]
    end

    validates_with NoAdditionalKeysValidator

    validates :instances, numericality: { only_integer: true }, allow_nil: true
    validates :memory_in_mb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :disk_in_mb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

    def self.create_from_http_request(body)
      ProcessScaleMessage.new(body.symbolize_keys)
    end
  end
end
