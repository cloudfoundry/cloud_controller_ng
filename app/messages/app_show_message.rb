require 'messages/base_message'

module VCAP::CloudController
  class AppShowMessage < BaseMessage
    ALLOWED_KEYS = [:include].freeze

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: ['space']
  end
end
