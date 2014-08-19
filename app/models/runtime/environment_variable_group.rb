module VCAP::CloudController
  class EnvironmentVariableGroup < Sequel::Model(:env_groups)
    plugin :serialization
    
    import_attributes :environment_json
    export_attributes :name, :environment_json

    serialize_attributes :json, :environment_json

    def self.running
      find_by_name(:running)
    end

    def self.staging
      find_by_name(:staging)
    end

    private 

    def self.find_by_name(group)
      EnvironmentVariableGroup.find_or_create(:name => group.to_s)
    end
  end
end
