Sequel.migration do
  up do
    alter_table(:env_groups) do
      add_column :salt, String
      set_column_allow_null(:environment_json)
      set_column_default(:environment_json, nil)
      set_column_type(:environment_json, 'text')
    end

    self[:env_groups].each do |row|
      salt = VCAP::CloudController::Encryptor.generate_salt
      encrypted = VCAP::CloudController::Encryptor.encrypt(row[:environment_json], salt)
      self['UPDATE env_groups SET environment_json = ?, salt = ? WHERE id = ?', encrypted, salt, row[:id]].update
    end
  end

  down do
    self[:env_groups].each do |row|
      decrypted = VCAP::CloudController::Encryptor.decrypt(row[:environment_json], row[:salt])
      self['UPDATE env_groups SET environment_json = ? WHERE id = ?', decrypted, row[:id]].update
    end

    alter_table(:env_groups) do
      set_column_allow_null(:environment_json, false)
      set_column_default(:environment_json, '{}')
      drop_column :salt
    end
  end
end
