require 'messages/list_message'

module VCAP::CloudController
  class AccessRulesListMessage < ListMessage
    register_allowed_keys %i[
      route_guids
      space_guids
      names
      selectors
      include
    ]

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: ['selector_resource', 'route']

    validates :space_guids, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w[route_guids space_guids names selectors include])
    end
  end
end
