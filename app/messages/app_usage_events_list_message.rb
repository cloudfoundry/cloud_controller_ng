require 'messages/list_message'

module VCAP::CloudController
  class AppUsageEventsListMessage < ListMessage
    register_allowed_keys [
      :guids,
    ]

    validates_with NoAdditionalParamsValidator

    validates :guids, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(guids))
    end
  end
end
