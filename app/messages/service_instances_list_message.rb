require 'messages/metadata_list_message'

module VCAP::CloudController
  class ServiceInstancesListMessage < MetadataListMessage
    register_allowed_keys [
      :names,
      :space_guids,
      :type,
      :service_plan_guids,
      :service_plan_names,
      :fields
    ]

    validates_with NoAdditionalParamsValidator

    validates :type, allow_nil: true, inclusion: {
        in: %w(managed user-provided),
        message: "must be one of 'managed', 'user-provided'"
      }

    validates :fields, allow_nil: true, fields: true

    def self.from_params(params)
      super(params, %w(names space_guids service_plan_guids service_plan_names))
    end

    def valid_order_by_values
      super << :name
    end
  end
end
