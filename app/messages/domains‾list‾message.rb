require 'messages/list_message'
require 'messages/validators/label_selector_requirement_validator'

module VCAP::CloudController
  class DomainsListMessage < ListMessage
    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      super(params, %w(names))
    end
  end
end
