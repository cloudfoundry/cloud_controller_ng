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
    ]
    @single_keys = [
      :available,
    ]

    register_allowed_keys(@single_keys + @array_keys)

    validates_with NoAdditionalParamsValidator
    validates :available, inclusion: { in: %w(true false), message: "only accepts values 'true' or 'false'" }, allow_nil: true

    def self.from_params(params)
      super(params, @array_keys.map(&:to_s))
    end

    def available?
      requested?(:available) && available == 'true'
    end
  end
end
