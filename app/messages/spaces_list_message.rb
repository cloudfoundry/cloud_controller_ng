require 'messages/metadata_list_message'

module VCAP::CloudController
  class SpacesListMessage < MetadataListMessage
    register_allowed_keys [
      :names,
      :organization_guids,
      :include,
    ]

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: ['org', 'organization']

    validates :names, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(names organization_guids include))
    end

    def valid_order_by_values
      super + [:name]
    end
  end
end
