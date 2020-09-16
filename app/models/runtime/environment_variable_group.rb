require 'messages/validators'

module VCAP::CloudController
  class EnvironmentVariableGroup < Sequel::Model(:env_groups)
    import_attributes :environment_json
    export_attributes :name, :environment_json

    set_field_as_encrypted :environment_json

    def self.running
      find_by_name(:running)
    end

    def self.staging
      find_by_name(:staging)
    end

    def validate
      return unless environment_json

      VCAP::CloudController::Validators::EnvironmentVariablesValidator.
        validate_each(self, :environment_json, environment_json)
    end

    def environment_json_with_serialization=(env)
      self.environment_json_without_serialization = MultiJson.dump(env)
    end
    alias_method 'environment_json_without_serialization=', 'environment_json='
    alias_method 'environment_json=', 'environment_json_with_serialization='

    def environment_json_with_serialization
      string = environment_json_without_serialization
      return {} if string.blank?

      MultiJson.load string
    end
    alias_method 'environment_json_without_serialization', 'environment_json'
    alias_method 'environment_json', 'environment_json_with_serialization'

    def self.find_by_name(group)
      EnvironmentVariableGroup.find_or_create(name: group.to_s)
    end
  end
end
