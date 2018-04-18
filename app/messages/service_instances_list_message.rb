require 'messages/list_message'

module VCAP::CloudController
  class ServiceInstancesListMessage < ListMessage
    register_allowed_keys [:page, :per_page, :order_by, :names, :space_guids]

    validates_with NoAdditionalParamsValidator
    validates :names, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true

    def self.from_params(params)
      opts = params.dup
      to_array! opts, 'names'
      to_array! opts, 'space_guids'
      new(opts.symbolize_keys)
    end

    def valid_order_by_values
      super << :name
    end
  end
end
