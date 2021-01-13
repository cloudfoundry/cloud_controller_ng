module VCAP::CloudController
  class EnvironmentVariableGroupUpdate
    class EnvironmentVariableGroupTooLong < StandardError
    end

    def patch(env_var_group, message)
      env_var_group.db.transaction do
        env_var_group.lock!

        env_var_group.environment_json = merge_environment_variables(env_var_group.environment_json || {}, message.var)
        env_var_group.save
      end

      env_var_group
    rescue Sequel::DatabaseError => e
      if e.message.include?("Mysql2::Error: Data too long for column 'environment_json'")
        raise EnvironmentVariableGroupTooLong
      end

      raise e
    end

    private

    def merge_environment_variables(existing_variables, new_variables)
      existing_variables.symbolize_keys.merge(new_variables).compact
    end
  end
end
