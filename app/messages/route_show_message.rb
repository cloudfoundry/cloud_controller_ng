require 'messages/base_message'

module VCAP::CloudController
  class RouteShowMessage < BaseMessage
    register_allowed_keys [:guid, :include]

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: ['domain', 'space', 'space.organization']

    validates :guid, presence: true, string: true

    def self.from_params(params)
      super(params, %w(include))
    end
  end
end
