require 'messages/list_message'

module VCAP::CloudController
  class UsageEventsListMessage < ListMessage
    register_allowed_keys [
      :types,
      :guids,
      :service_instance_types,
      :service_offering_guids
    ]

    validates_with NoAdditionalParamsValidator

    validates :types, array: true, allow_nil: true
    validates :guids, array: true, allow_nil: true
    validates :service_instance_types, array: true, allow_nil: true
    validates :service_offering_guids, array: true, allow_nil: true

    def self.from_params(params)
      params['order_by'] ||= 'created_at'
      super(params, %w(types guids service_instance_types service_offering_guids))
    end
  end
end
