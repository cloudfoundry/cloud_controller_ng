require 'messages/list_message'

module VCAP::CloudController
  class ServiceCredentialBindingsListMessage < ListMessage
    ARRAY_KEYS = [
      :names,
      :service_instance_guids,
      :service_instance_names,
      :app_guids,
      :app_names,
      :include
    ].freeze

    SINGLE_KEYS = [
      :type
    ].freeze

    register_allowed_keys ARRAY_KEYS + SINGLE_KEYS

    validates_with NoAdditionalParamsValidator
    validates :type, allow_nil: true, inclusion: { in: %w(app key), message: "must be one of 'app', 'key'" }
    validates_with IncludeParamValidator, valid_values: %w(app)

    def self.from_params(params)
      super(params, ARRAY_KEYS.map(&:to_s))
    end
  end
end
