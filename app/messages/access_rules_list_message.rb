require 'messages/list_message'

module VCAP::CloudController
  class AccessRulesListMessage < ListMessage
    register_allowed_keys %i[
      route_guids
      names
      selectors
    ]

    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      super(params, %w[route_guids names selectors])
    end
  end
end
