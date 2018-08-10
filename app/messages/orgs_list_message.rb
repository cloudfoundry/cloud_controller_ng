require 'messages/list_message'

module VCAP::CloudController
  class OrgsListMessage < ListMessage
    register_allowed_keys [:page, :per_page, :names, :guids, :order_by, :isolation_segment_guid]

    validates_with NoAdditionalParamsValidator

    validates :names, array: true, allow_nil: true
    validates :guids, array: true, allow_nil: true

    def to_param_hash
      super(exclude: [:page, :per_page, :order_by, :isolation_segment_guid])
    end

    def self.from_params(params)
      opts = params.dup
      to_array! opts, 'names'
      to_array! opts, 'guids'
      new(opts.symbolize_keys)
    end

    def valid_order_by_values
      super << :name
    end
  end
end
