require 'messages/base_message'

module VCAP::CloudController
  class ServiceBindingsListMessage < BaseMessage
    ALLOWED_KEYS = [:page, :per_page, :order_by].freeze
    VALID_ORDER_BY_KEYS = /created_at|updated_at/

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalParamsValidator
    validates_numericality_of :page, greater_than: 0, allow_nil: true, only_integer: true
    validates_numericality_of :per_page, greater_than: 0, allow_nil: true, only_integer: true
    validates_format_of :order_by, with: /[+-]?(#{VALID_ORDER_BY_KEYS})/, allow_nil: true

    def self.from_params(params)
      opts = params.dup

      new(opts.symbolize_keys)
    end

    def initialize(params={})
      super(params.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
