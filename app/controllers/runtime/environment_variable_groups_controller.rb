module VCAP::CloudController
  class EnvironmentVariableGroupsController < RestController::ModelController
    def self.path
      "#{ROUTE_PREFIX}/config/environment_variable_groups"
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
      [ HTTP::OK, group.environment_json.to_json ]
    end

    def update(group)
      validate_access(:update, model)

      begin
        group.environment_json = MultiJson.load(body)
        group.save
      rescue  MultiJson::ParseError => e
        raise Errors::ApiError.new_from_details("MessageParseError", e.message)
      end

      [ HTTP::OK, group.environment_json.to_json ]
    end
  end
end
