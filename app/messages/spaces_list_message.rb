require 'messages/list_message'

module VCAP::CloudController
  class SpacesListMessage < ListMessage
    register_allowed_keys [:page, :per_page, :order_by, :names, :organization_guids, :guids]

    validates_with NoAdditionalParamsValidator

    validates :names, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true
    validates :guids, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(names organization_guids guids))
    end

    def valid_order_by_values
      super << :name
    end
  end
end
