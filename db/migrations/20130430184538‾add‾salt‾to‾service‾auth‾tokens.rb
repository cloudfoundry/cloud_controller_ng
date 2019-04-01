Sequel.migration do
  up do
    alter_table :service_auth_tokens do
      add_column :salt, String
    end

    self[:service_auth_tokens].each do |service_auth_token|
      generated_salt = VCAP::CloudController::Encryptor.generate_salt
      self[:service_auth_tokens].filter(id: service_auth_token[:id]).update(
        salt: generated_salt,
        token: VCAP::CloudController::Encryptor.encrypt(service_auth_token[:token], generated_salt)
      )
    end
  end

  down do
    self[:service_auth_tokens].each do |service_auth_token|
      self[:service_auth_tokens].filter(id: service_auth_token[:id]).update(
        token: VCAP::CloudController::Encryptor.decrypt(service_auth_token[:token], service_auth_token[:salt])
      )
    end

    alter_table :service_auth_tokens do
      drop_column :salt
    end
  end
end
