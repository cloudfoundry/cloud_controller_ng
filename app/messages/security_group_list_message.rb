require 'messages/list_message'

module VCAP::CloudController
  class SecurityGroupListMessage < ListMessage
    register_allowed_keys []

    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      super(params, %w())
    end
  end
end
