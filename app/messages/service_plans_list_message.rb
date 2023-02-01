require 'messages/metadata_list_message'
require 'messages/validators/label_selector_requirement_validator'

module VCAP::CloudController
  class ServicePlansListMessage < MetadataListMessage
    @array_keys = [
      :broker_catalog_ids,
      :names,
      :organization_guids,
      :service_broker_guids,
      :service_broker_names,
      :service_instance_guids,
      :service_offering_guids,
      :service_offering_names,
      :space_guids,
      :include
    ]
    @single_keys = [
      :available,
      :fields
    ]

    register_allowed_keys(@single_keys + @array_keys)

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: %w(space.organization service_offering)
    validates :available, boolean_string: true, allow_nil: true

    validates :fields, allow_nil: true, fields: {
      allowed: {
        'service_offering.service_broker' => ['guid', 'name']
      }
    }

    def valid_order_by_values
      super + [:name]
    end

    def self.from_params(params)
      super(params, @array_keys.map(&:to_s), fields: %w(fields))
    end

    def to_param_hash
      super(fields: [:fields])
    end

    def available?
      requested?(:available) && available == 'true'
    end
  end
end
