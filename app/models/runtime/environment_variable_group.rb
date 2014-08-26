module VCAP::CloudController
  class EnvironmentVariableGroup < Sequel::Model(:env_groups)
    import_attributes :environment_json
    export_attributes :name, :environment_json

    def self.running
      find_by_name(:running)
    end

    def self.staging
      find_by_name(:staging)
    end

    def environment_json=(env)
      generate_salt
      super VCAP::CloudController::Encryptor.encrypt(MultiJson.dump(env), salt)
    end

    def environment_json
      raw_value = super
      return {} unless raw_value

      MultiJson.load(VCAP::CloudController::Encryptor.decrypt(raw_value, salt))
    end

    private

    def generate_salt
      self.salt ||= VCAP::CloudController::Encryptor.generate_salt.freeze
    end

    def self.find_by_name(group)
      EnvironmentVariableGroup.find_or_create(:name => group.to_s)
    end
  end
end
