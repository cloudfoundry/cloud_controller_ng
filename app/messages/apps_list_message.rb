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
      :lifecycle_type,
      :created_ats,
      :updated_ats
    ]

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: ['space', 'org', 'space.organization']
    validates_with LifecycleTypeParamValidator

    validates :names, array: true, allow_nil: true
    validates :guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true
    validates :stacks, array: true, allow_nil: true
    validates :created_ats, timestamp: true, allow_nil: true
    validates :updated_ats, timestamp: true, allow_nil: true

    def valid_order_by_values
      super << :name
    end

    def self.from_params(params)
      super(params, %w(names guids organization_guids space_guids stacks include created_ats updated_ats))
    end
  end
end
