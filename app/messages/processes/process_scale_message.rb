require 'messages/base_message'

module VCAP::CloudController
  module SharedProcessScaleValidators
    def self.included(base)
      base.class_eval do
        validates :instances, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
      end
    end
  end

  class ProcessScaleMessage < BaseMessage
    ALLOWED_KEYS = [:instances, :memory_in_mb, :disk_in_mb].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator

    include SharedProcessScaleValidators
    validates :memory_in_mb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :disk_in_mb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

    def self.create_from_http_request(body)
      ProcessScaleMessage.new(body.deep_symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
