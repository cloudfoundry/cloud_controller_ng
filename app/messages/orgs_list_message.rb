require 'messages/metadata_list_message'

module VCAP::CloudController
  class OrgsListMessage < MetadataListMessage
    register_allowed_keys [
      :names,
      :isolation_segment_guid,
    ]

    validates_with NoAdditionalParamsValidator

    validates :names, array: true, allow_nil: true

    def to_param_hash
      super(exclude: [:isolation_segment_guid])
    end

    def self.from_params(params)
      super(params, %w(names))
    end

    def valid_order_by_values
      super + [:name]
    end
  end
end
