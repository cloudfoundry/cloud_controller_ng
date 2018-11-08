require 'messages/list_message'

module VCAP::CloudController
  class AppsListMessage < ListMessage
    register_allowed_keys [
      :names,
      :guids,
      :organization_guids,
      :space_guids,
      :page,
      :per_page,
      :order_by,
      :order_direction,
      :include,
      :label_selector,
    ]

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: ['space']
    validates_with LabelSelectorRequirementValidator, if: label_selector_requested?

    validates :names, array: true, allow_nil: true
    validates :guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true

    def to_param_hash
      super(exclude: [:page, :per_page, :order_by])
    end

    def valid_order_by_values
      super << :name
    end

    def self.from_params(params)
      super(params, %w(names guids organization_guids space_guids))
    end
  end
end
