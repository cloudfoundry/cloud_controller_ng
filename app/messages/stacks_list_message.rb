require 'messages/metadata_list_message'

module VCAP::CloudController
  class StacksListMessage < MetadataListMessage
    register_allowed_keys [:names, :default,]

    validates_with NoAdditionalParamsValidator

    validates :names, array: true, allow_nil: true
    validates :default, boolean_string: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(names))
    end

    def valid_order_by_values
      super + [:name]
    end
  end
end
