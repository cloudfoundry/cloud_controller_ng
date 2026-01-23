require 'messages/base_message'

module VCAP::CloudController
  class ProcessShowMessage < BaseMessage
    register_allowed_keys [:embed]

    validates_with NoAdditionalParamsValidator
    validates_with EmbedParamValidator, valid_values: ['process_instances']

    def self.from_params(params)
      super(params, %w[embed])
    end
  end
end
