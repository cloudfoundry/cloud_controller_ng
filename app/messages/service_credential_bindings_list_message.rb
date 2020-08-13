require 'messages/list_message'

module VCAP::CloudController
  class ServiceCredentialBindingsListMessage < ListMessage
    register_allowed_keys [
      :names,
      :service_instance_guids,
      :service_instance_names,
    ]

    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      super(params, %w(names service_instance_guids service_instance_names))
    end
  end
end
