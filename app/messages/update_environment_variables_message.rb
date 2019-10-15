require 'messages/base_message'

module VCAP::CloudController
  class UpdateEnvironmentVariablesMessage < BaseMessage
    register_allowed_keys [:var]

    validates_with NoAdditionalKeysValidator
    validates_with StringValuesOnlyValidator

    validates :var, environment_variables: true

    def initialize(params, opts={})
      if (params == {}) && opts[:populate_empty_hash_with_empty_var]
        params = { var: {} }
      end
      super(params)
    end

    def audit_hash
      result = super
      result['environment_variables'] = result.delete('var')
      result
    end
  end
end
