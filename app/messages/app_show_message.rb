require 'messages/base_message'

module VCAP::CloudController
  class AppShowMessage < BaseMessage
    register_allowed_keys [:include]

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: ['space']

    def initialize(params)
      super
      if self.requested?(:include)
        self.include = self.include.split(',')
      end
    end
  end
end
