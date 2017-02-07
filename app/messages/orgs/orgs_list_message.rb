require 'messages/list_message'

module VCAP::CloudController
  class OrgsListMessage < ListMessage
    ALLOWED_KEYS = [:page, :per_page, :names, :isolation_segment_guid].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalParamsValidator

    validates :names, array: true, allow_nil: true

    def initialize(params={})
      super(params.symbolize_keys)
    end

    def to_param_hash
      super(exclude: [:page, :per_page, :isolation_segment_guid])
    end

    def self.from_params(params)
      opts = params.dup
      to_array! opts, 'names'
      new(opts.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
