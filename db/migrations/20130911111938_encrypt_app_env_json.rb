require File.expand_path('../../../lib/cloud_controller/encryptor', __FILE__)

Sequel.migration do
  up do
    self[:apps].each do |row|
      salt = VCAP::CloudController::Encryptor.generate_salt
      encrypted = VCAP::CloudController::Encryptor.encrypt(row[:environment_json], salt)
      self['UPDATE apps SET encrypted_environment_json = ?, salt = ? WHERE id = ?', encrypted, salt, row[:id]].update
    end

    alter_table :apps do
      drop_column :environment_json
    end
  end

  down do
    alter_table :apps do
      if Sequel::Model.db.database_type == :mssql
        add_column :environment_json, String, size: :max
      else
        add_column :environment_json, :text
      end
    end

    self[:apps].each do |row|
      decrypted = VCAP::CloudController::Encryptor.decrypt(row[:encrypted_environment_json], row[:salt])
      self['UPDATE apps SET environment_json = ? WHERE id = ?', decrypted, row[:id]].update
    end
  end
end
