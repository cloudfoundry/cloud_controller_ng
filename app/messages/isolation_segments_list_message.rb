require 'messages/metadata_list_message'

module VCAP::CloudController
  class IsolationSegmentsListMessage < MetadataListMessage
    register_allowed_keys [
      :names,
      :guids,
      :organization_guids,
      :created_ats,
      :updated_ats,
    ]

    validates_with NoAdditionalParamsValidator

    validates :names, array: true, allow_nil: true
    validates :guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true
    validates :created_ats, timestamp: true, allow_nil: true
    validates :updated_ats, timestamp: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(names guids organization_guids created_ats updated_ats))
    end

    def valid_order_by_values
      super << :name
    end
  end
end
