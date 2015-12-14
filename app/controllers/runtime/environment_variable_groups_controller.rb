module VCAP::CloudController
  class EnvironmentVariableGroupsController < RestController::ModelController
    def self.path
      "#{V2_ROUTE_PREFIX}/config/environment_variable_groups"
    end

    get "#{path}/staging", :read_staging
    def read_staging
      read(EnvironmentVariableGroup.staging)
    end

    put "#{path}/staging", :update_staging
    def update_staging
      update(EnvironmentVariableGroup.staging)
    end

    get "#{path}/running", :read_running
    def read_running
      read(EnvironmentVariableGroup.running)
    end

    put "#{path}/running", :update_running
    def update_running
      update(EnvironmentVariableGroup.running)
    end

    private

    def read(group)
      validate_access(:read, model)
      [HTTP::OK, MultiJson.dump(group.environment_json, pretty: true)]
    end

    def update(group)
      validate_access(:update, model)

      begin
        json_req = MultiJson.load(body)
      rescue MultiJson::ParseError => e
        raise Errors::ApiError.new_from_details('MessageParseError', e.message)
      end

      if json_req.nil?
        raise Errors::ApiError.new_from_details('EnvironmentVariableGroupInvalid', "Cannot be 'null'. You may want to try empty object '{}' to clear the group.")
      end

      group.environment_json = json_req
      group.save

      [HTTP::OK, MultiJson.dump(group.environment_json, pretty: true)]
    end
  end
end
