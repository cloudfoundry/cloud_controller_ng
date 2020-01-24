require 'messages/list_message'

module VCAP::CloudController
  class SpaceQuotasListMessage < ListMessage
    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      super(params, [])
    end
  end
end
