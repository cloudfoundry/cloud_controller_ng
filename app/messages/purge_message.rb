require 'messages/base_message'

module VCAP::CloudController
  class PurgeMessage < BaseMessage
    register_allowed_keys [
      :purge,
    ]

    validates_with NoAdditionalParamsValidator
    validates :purge, boolean_string: true, allow_nil: true

    def self.from_params(params)
      super(params, [])
    end

    def purge?
      purge == 'true'
    end
  end
end
