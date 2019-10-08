module VCAP::CloudController
  class EnvironmentVariableGroupUpdate
    class InvalidEnvironmentVariableGroup < StandardError
    end

    def patch(env_var_group, message)
      env_var_group.db.transaction do
        env_var_group.lock!

        env_var_group.environment_json = merge_environment_variables(env_var_group.environment_json || {}, message.var)
        env_var_group.save
      end

      env_var_group
    rescue Sequel::ValidationFailed => e
      raise InvalidEnvironmentVariableGroup.new(e.message)
    end

    private

    def merge_environment_variables(existing_variables, new_variables)
      existing_variables.symbolize_keys.merge(new_variables).reject { |_, v| v.nil? }
    end
  end
end
