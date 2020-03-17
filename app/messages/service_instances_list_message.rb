require 'messages/metadata_list_message'

module VCAP::CloudController
  class ServiceInstancesListMessage < MetadataListMessage
    register_allowed_keys [
      :names,
      :space_guids,
      :type,
    ]

    validates_with NoAdditionalParamsValidator

    validates :type, allow_nil: true, inclusion: {
        in: %w(managed user-provided),
        message: "must be one of 'managed', 'user-provided'"
      }

    def self.from_params(params)
      super(params, %w(names space_guids))
    end

    def valid_order_by_values
      super << :name
    end
  end
end
