require 'cloud_controller/encryptor'

Sequel.migration do
  up do
    alter_table :service_bindings do
      add_column :salt, String
    end

    self[:service_bindings].each do |service_binding|
      generated_salt = VCAP::CloudController::Encryptor.generate_salt
      self[:service_bindings].filter(id: service_binding[:id]).update(
        salt: generated_salt,
        credentials: VCAP::CloudController::Encryptor.encrypt(service_binding[:credentials], generated_salt)
      )
    end
  end

  down do
    self[:service_bindings].each do |service_binding|
      self[:service_bindings].filter(id: service_binding[:id]).update(
        credentials: VCAP::CloudController::Encryptor.decrypt(service_binding[:credentials], service_binding[:salt])
      )
    end

    alter_table :service_bindings do
      drop_column :salt
    end
  end
end
