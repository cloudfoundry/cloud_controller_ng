require 'messages/list_message'

module VCAP::CloudController
  class SpacesListMessage < ListMessage
    register_allowed_keys [:page, :per_page, :order_by, :names, :organization_guids, :guids]

    validates_with NoAdditionalParamsValidator

    validates :names, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true
    validates :guids, array: true, allow_nil: true

    def self.from_params(params)
      opts = params.dup
      to_array! opts, 'names'
      to_array! opts, 'organization_guids'
      to_array! opts, 'guids'
      new(opts.symbolize_keys)
    end

    def valid_order_by_values
      super << :name
    end
  end
end
