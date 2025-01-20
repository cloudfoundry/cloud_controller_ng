require 'messages/list_message'

module VCAP::CloudController
  class AppUsageEventsListMessage < ListMessage
    register_allowed_keys %i[
      after_guid
      consumer_guid
    ]

    validates_with NoAdditionalParamsValidator
    validates_with DisallowUpdatedAtsParamValidator

    validates :after_guid, array: true, allow_nil: true, length: {
      is: 1,
      wrong_length: 'filter accepts only one guid'
    }

    def valid_order_by_values
      [:created_at]
    end

    def self.from_params(params)
      super(params, %w[after_guid consumer_guid])
    end
  end
end
