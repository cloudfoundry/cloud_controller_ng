require 'messages/base_message'

module VCAP::CloudController
  class RouteMappingsListMessage < BaseMessage
    ALLOWED_KEYS = [:page, :per_page].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalParamsValidator

    validates_numericality_of :page, greater_than: 0, allow_nil: true, only_integer: true
    validates_numericality_of :per_page, greater_than: 0, allow_nil: true, only_integer: true

    def initialize(params={})
      super(params.symbolize_keys)
    end

    def to_param_hash
      super(exclude: [:page, :per_page, :order_by])
    end

    def self.from_params(params)
      opts = params.dup
      new(opts.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
