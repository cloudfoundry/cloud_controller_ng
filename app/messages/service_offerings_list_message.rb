require 'messages/metadata_list_message'
require 'messages/validators/label_selector_requirement_validator'

module VCAP::CloudController
  class ServiceOfferingsListMessage < MetadataListMessage
    register_allowed_keys [
      :available,
    ]

    validates_with NoAdditionalParamsValidator

    validates :available, inclusion: { in: %w(true false), message: "only accepts values 'true' or 'false'" }, allow_nil: true

    def self.from_params(params)
      super(params, %w())
    end
  end
end
