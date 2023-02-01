require 'messages/metadata_list_message'
require 'messages/validators/label_selector_requirement_validator'

module VCAP::CloudController
  class ServiceOfferingsListMessage < MetadataListMessage
    @array_keys = [
      :service_broker_guids,
      :service_broker_names,
      :names,
      :space_guids,
      :organization_guids,
    ]

    @single_keys = [
      :available,
      :fields
    ]

    register_allowed_keys(@single_keys + @array_keys)

    validates_with NoAdditionalParamsValidator
    validates :available, boolean_string: true, allow_nil: true

    validates :fields, allow_nil: true, fields: {
      allowed: {
        'service_broker' => ['guid', 'name']
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

    def pagination_options
      super.tap do |po|
        if po.order_by == 'name'
          po.order_by = 'label'
        end
      end
    end

    def available?
      requested?(:available) && available == 'true'
    end
  end
end
