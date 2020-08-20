require 'messages/metadata_list_message'
require 'messages/validators/label_selector_requirement_validator'

module VCAP::CloudController
  class ServiceBrokersListMessage < MetadataListMessage
    register_allowed_keys [
      :space_guids,
      :names
    ]

    validates_with NoAdditionalParamsValidator

    validates :space_guids, array: true, allow_nil: true
    validates :names, array: true, allow_nil: true

    def valid_order_by_values
      super + [:name]
    end

    def self.from_params(params)
      super(params, %w(names space_guids))
    end
  end
end
