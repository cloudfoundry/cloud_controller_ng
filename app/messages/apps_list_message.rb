require 'messages/metadata_list_message'

module VCAP::CloudController
  class AppsListMessage < MetadataListMessage
    register_allowed_keys [
      :names,
      :guids,
      :organization_guids,
      :space_guids,
      :stacks,
      :include,
    ]

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: ['space', 'org']

    validates :names, array: true, allow_nil: true
    validates :guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true
    validates :stacks, array: true, allow_nil: true

    def valid_order_by_values
      super << :name
    end

    def self.from_params(params)
      super(params, %w(names guids organization_guids space_guids stacks include))
    end
  end
end
