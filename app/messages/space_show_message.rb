require 'messages/metadata_list_message'

module VCAP::CloudController
  class SpaceShowMessage < BaseMessage
    register_allowed_keys [:include]

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: ['org', 'organization']

    def self.from_params(params)
      super(params, %w(include))
    end
  end
end
