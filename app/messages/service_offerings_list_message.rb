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
    validates :available, inclusion: { in: %w(true false), message: "only accepts values 'true' or 'false'" }, allow_nil: true

    validates :fields, allow_nil: true, fields: {
      allowed: {
        'service_broker' => ['guid', 'name']
      }
    }

    def self.from_params(params)
      super(params, @array_keys.map(&:to_s), fields: %w(fields))
    end
  end
end
