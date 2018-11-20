require 'messages/list_message'

module VCAP::CloudController
  class ServiceBindingsListMessage < ListMessage
    register_allowed_keys [
      :app_guids,
      :service_instance_guids,
    ]

    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      super(params, %w(app_guids service_instance_guids))
    end
  end
end
