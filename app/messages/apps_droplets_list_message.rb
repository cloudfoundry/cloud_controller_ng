require 'messages/base_message'

module VCAP::CloudController
  class AppsDropletsListMessage < BaseMessage
    ALLOWED_KEYS = [:states, :page, :per_page, :order_by]

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalParamsValidator

    validates :states, array: true, allow_nil: true
    validates_numericality_of :page, greater_than: 0, allow_nil: true, only_integer: true
    validates_numericality_of :per_page, greater_than: 0, allow_nil: true, only_integer: true
    validates :order_by, string: true, allow_nil: true

    def initialize(params={})
      super(params.symbolize_keys)
    end

    def to_param_hash
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
