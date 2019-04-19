require 'messages/list_message'
require 'messages/validators/label_selector_requirement_validator'

module VCAP::CloudController
  class DomainsListMessage < ListMessage
    register_allowed_keys [
      :names
    ]

    validates_with NoAdditionalParamsValidator
    validates :names, allow_nil: true, array: true

    def self.from_params(params)
      super(params, %w(names))
    end
  end
end
