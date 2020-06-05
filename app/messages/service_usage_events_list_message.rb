require 'messages/list_message'

module VCAP::CloudController
  class ServiceUsageEventsListMessage < ListMessage
    register_allowed_keys [
      :guids,
      :service_instance_types,
      :service_offering_guids,
    ]

    validates_with NoAdditionalParamsValidator

    validates :guids, array: true, allow_nil: true
    validates :service_instance_types, array: true, allow_nil: true
    validates :service_offering_guids, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(guids service_instance_types service_offering_guids))
    end
  end
end
