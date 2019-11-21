require 'messages/base_message'

module VCAP::CloudController
  class UpdateEnvironmentVariablesMessage < BaseMessage
    register_allowed_keys [:var]

    validates_with NoAdditionalKeysValidator

    validates :var, environment_variables_string_values: true

    def self.for_env_var_group(params)
      if params == {}
        params = { var: {} }
      end
      self.new(params)
    end

    def audit_hash
      result = super
      result['environment_variables'] = result.delete('var')
      result
    end
  end
end
