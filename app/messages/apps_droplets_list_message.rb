require 'messages/base_message'

module VCAP::CloudController
  class AppsDropletsListMessage < BaseMessage
    ALLOWED_KEYS = [:states, :page, :per_page, :order_by]
    VALID_ORDER_BY_KEYS = /created_at|updated_at/

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalParamsValidator

    validates :states, array: true, allow_nil: true
    validates_numericality_of :page, greater_than: 0, allow_nil: true
    validates_numericality_of :per_page, greater_than: 0, allow_nil: true
    validates_format_of :order_by, with: /[+-]?(#{VALID_ORDER_BY_KEYS})/, allow_nil: true

    def initialize(params={})
      super(params.symbolize_keys)
    end

    def to_params
      super(exclude: [:page, :per_page, :order_by])
    end

    def self.from_params(params)
      opts = params.dup
      to_array!(opts, 'states')

      new(opts.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
