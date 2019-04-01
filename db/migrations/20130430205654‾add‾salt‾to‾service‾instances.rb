require 'cloud_controller/encryptor'

Sequel.migration do
  up do
    alter_table :service_instances do
      add_column :salt, String
    end

    self[:service_instances].each do |service_instance|
      generated_salt = VCAP::CloudController::Encryptor.generate_salt
      self[:service_instances].filter(id: service_instance[:id]).update(
        salt: generated_salt,
        credentials: VCAP::CloudController::Encryptor.encrypt(service_instance[:credentials], generated_salt)
      )
    end
  end

  down do
    self[:service_instances].each do |service_instance|
      self[:service_instances].filter(id: service_instance[:id]).update(
        credentials: VCAP::CloudController::Encryptor.decrypt(service_instance[:credentials], service_instance[:salt])
      )
    end

    alter_table :service_instances do
      drop_column :salt
    end
  end
end
