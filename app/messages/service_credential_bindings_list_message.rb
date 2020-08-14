require 'messages/list_message'

module VCAP::CloudController
  class ServiceCredentialBindingsListMessage < ListMessage
    register_allowed_keys [
      :names,
      :service_instance_guids,
      :service_instance_names,
      :app_guids,
      :app_names,
      :type
    ]

    validates_with NoAdditionalParamsValidator
    validates :type, allow_nil: true, inclusion: { in: %w(app key), message: "must be one of 'app', 'key'" }

    def self.from_params(params)
      super(params, %w(names service_instance_guids service_instance_names app_guids app_names))
    end
  end
end
