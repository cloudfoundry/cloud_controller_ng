require 'messages/base_message'

module VCAP::CloudController
  class AppShowMessage < BaseMessage
    ALLOWED_KEYS = [:include].freeze

    attr_accessor(*ALLOWED_KEYS)

    def initialize(params={})
      # do we need this? no
      super(params.symbolize_keys)
    end

    validates_with NoAdditionalParamsValidator
    validates_with IncludeParamValidator, valid_values: ['space']

    def self.from_params(params)
      new(params.dup.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
