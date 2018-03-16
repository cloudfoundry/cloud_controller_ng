require 'messages/base_message'

module VCAP::CloudController
  class ManifestProcessScaleMessage < BaseMessage
    ALLOWED_KEYS = [:instances, :memory, :disk_quota].freeze
    INVALID_MB_VALUE_ERROR = 'must be greater than 0MB'.freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator

    validates :instances, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :memory, numericality: { only_integer: true, greater_than: 0, message: INVALID_MB_VALUE_ERROR }, allow_nil: true
    validates :disk_quota, numericality: { only_integer: true, greater_than: 0, message: INVALID_MB_VALUE_ERROR }, allow_nil: true

    def self.create_from_http_request(body)
      ManifestProcessScaleMessage.new(body.deep_symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
