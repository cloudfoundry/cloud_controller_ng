require 'messages/list_message'

module VCAP::CloudController
  class IsolationSegmentsListMessage < ListMessage
    ALLOWED_KEYS = [:names, :guids, :page, :per_page, :order_by, :order_direction].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalParamsValidator

    validates :names, array: true, allow_nil: true
    validates :guids, array: true, allow_nil: true

    def initialize(params={})
      super(params.symbolize_keys)
    end

    def to_param_hash
      super(exclude: [:page, :per_page, :order_by])
    end

    def self.from_params(params)
      opts = params.dup
      %w(names guids).each do |attribute|
        to_array! opts, attribute
      end
      new(opts.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
