require 'messages/metadata_list_message'

module VCAP::CloudController
  class ServiceInstancesListMessage < MetadataListMessage
    @array_keys = [
      :names,
      :space_guids,
      :organization_guids,
      :service_plan_guids,
      :service_plan_names,
    ]

    @single_keys = [
      :type,
      :fields
    ]

    register_allowed_keys(@single_keys + @array_keys)

    validates_with NoAdditionalParamsValidator

    validates :type, allow_nil: true, inclusion: {
      in: %w(managed user-provided),
      message: "must be one of 'managed', 'user-provided'"
    }

    validates :fields, allow_nil: true, fields: {
      allowed: {
        'space' => %w(guid name relationships.organization),
        'space.organization' => %w(name guid),
        'service_plan' => %w(guid name relationships.service_offering),
        'service_plan.service_offering' => %w(name guid description documentation_url tags relationships.service_broker),
        'service_plan.service_offering.service_broker' => %w(name guid)
      }
    }

    def self.from_params(params)
      super(params, @array_keys.map(&:to_s), fields: %w(fields))
    end

    def to_param_hash
      super(fields: [:fields])
    end

    def valid_order_by_values
      super + [:name]
    end
  end
end
