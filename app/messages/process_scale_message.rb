require 'messages/base_message'

module VCAP::CloudController
  class ProcessScaleMessage < BaseMessage
    ALLOWED_KEYS = [:instances, :memory_in_mb, :disk_in_mb].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator, ManifestValidator

    validates :instances, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

    def self.create_from_http_request(body)
      ProcessScaleMessage.new(body.deep_symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
