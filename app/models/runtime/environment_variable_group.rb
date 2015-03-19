module VCAP::CloudController
  class EnvironmentVariableGroup < Sequel::Model(:env_groups)
    import_attributes :environment_json
    export_attributes :name, :environment_json

    encrypt :environment_json, salt: :salt

    def self.running
      find_by_name(:running)
    end

    def self.staging
      find_by_name(:staging)
    end

    def environment_json_with_serialization
      environment_variables = environment_json_without_serialization
      return environment_variables if environment_variables.is_a?(Hash)
      return {} if environment_variables.blank?
      MultiJson.load environment_variables
    end
    alias_method_chain :environment_json, 'serialization'

    def self.find_by_name(group)
      EnvironmentVariableGroup.find_or_create(name: group.to_s)
    end
  end
end
