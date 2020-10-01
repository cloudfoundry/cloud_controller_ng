require 'messages/metadata_list_message'

module VCAP::CloudController
  class AppsListMessage < MetadataListMessage
    register_allowed_keys [
      :names,
      :organization_guids,
      :space_guids,
      :stacks,
      :include,
      :lifecycle_type
    ]

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: ['space', 'org', 'space.organization']
    validates_with LifecycleTypeParamValidator

    validates :names, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true
    validates :stacks, array: true, allow_nil: true

    def valid_order_by_values
      super + [:name, :state]
    end

    def self.from_params(params)
      super(params, %w(names organization_guids space_guids stacks include))
    end

    def pagination_options
      super.tap do |po|
        if po.order_by == 'state'
          po.order_by = 'desired_state'
        end
      end
    end
  end
end
