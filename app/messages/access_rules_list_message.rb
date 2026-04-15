require 'messages/list_message'

module VCAP::CloudController
  class AccessRulesListMessage < ListMessage
    register_allowed_keys %i[
      guids
      route_guids
      space_guids
      selectors
      selector_resource_guids
      include
    ]

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: %w[selector_resource route app space organization]

    validates :space_guids, array: true, allow_nil: true
    validates :selector_resource_guids, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w[route_guids space_guids selectors selector_resource_guids include])
    end
  end
end
