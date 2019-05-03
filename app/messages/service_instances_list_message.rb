require 'messages/metadata_list_message'

module VCAP::CloudController
  class ServiceInstancesListMessage < MetadataListMessage
    register_allowed_keys [
      :names,
      :space_guids,
    ]

    validates_with NoAdditionalParamsValidator

    validates :names, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(names space_guids))
    end

    def valid_order_by_values
      super << :name
    end
  end
end
