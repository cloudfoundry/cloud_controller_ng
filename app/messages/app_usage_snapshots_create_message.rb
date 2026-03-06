require 'messages/base_message'

module VCAP::CloudController
  class AppUsageSnapshotsCreateMessage < BaseMessage
    register_allowed_keys []

    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      super(params, [])
    end
  end
end
