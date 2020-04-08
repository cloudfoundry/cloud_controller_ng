require 'messages/base_message'

module VCAP::CloudController
  class RouteDestinationsListMessage < BaseMessage
    register_allowed_keys [
      :guids,
      :app_guids,
    ]

    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      super(params, %w(guids app_guids))
    end
  end
end
