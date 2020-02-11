require 'messages/metadata_list_message'
require 'messages/validators/label_selector_requirement_validator'

module VCAP::CloudController
  class ServicePlansListMessage < MetadataListMessage
    register_allowed_keys [
      :names,
      :available,
      :space_guids,
      :organization_guids,
      :service_broker_guids,
      :service_broker_names,
      :service_offering_guids,
      :broker_catalog_ids,
    ]

    validates_with NoAdditionalParamsValidator
    validates :available, inclusion: { in: %w(true false), message: "only accepts values 'true' or 'false'" }, allow_nil: true

    def self.from_params(params)
      super(params, %w(names space_guids organization_guids service_broker_guids service_broker_names service_offering_guids broker_catalog_ids))
    end

    def available?
      requested?(:available) && available == 'true'
    end
  end
end
