require 'messages/base_message'

module VCAP::CloudController
  class RoleShowMessage < BaseMessage
    register_allowed_keys [:include]

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: %w(user organization space)

    def self.from_params(params)
      super(params, %w(include))
    end
  end
end
