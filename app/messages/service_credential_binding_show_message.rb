require 'messages/base_message'

module VCAP::CloudController
  class ServiceCredentialBindingShowMessage < BaseMessage
    ARRAY_KEYS = [
      :include
    ].freeze

    register_allowed_keys ARRAY_KEYS

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: %w(app service_instance)

    def self.from_params(params)
      super(params, ARRAY_KEYS.map(&:to_s))
    end
  end
end
