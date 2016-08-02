Sequel.migration do
  up do
    alter_table(:buildpack_lifecycle_data) do
      add_column :salt, String
      add_column :encrypted_buildpack, String
    end

    self[:buildpack_lifecycle_data].each do |row|
      salt = VCAP::CloudController::Encryptor.generate_salt
      encrypted = VCAP::CloudController::Encryptor.encrypt(row[:buildpack], salt)
      self['UPDATE buildpack_lifecycle_data SET encrypted_buildpack = ?, salt = ? WHERE id = ?', encrypted, salt, row[:id]].update
    end

    alter_table :buildpack_lifecycle_data do
      drop_column :buildpack
    end

    alter_table(:apps) do
      add_column :buildpack_salt, String
      add_column :encrypted_buildpack, String
    end

    self[:apps].each do |row|
      salt = VCAP::CloudController::Encryptor.generate_salt
      encrypted = VCAP::CloudController::Encryptor.encrypt(row[:buildpack], salt)
      self['UPDATE apps SET encrypted_buildpack = ?, buildpack_salt = ? WHERE id = ?', encrypted, salt, row[:id]].update
    end

    alter_table :apps do
      drop_column :buildpack
    end
  end

  down do
    alter_table(:buildpack_lifecycle_data) do
      add_column :buildpack
    end

    self[:buildpack_lifecycle_data].each do |row|
      decrypted = VCAP::CloudController::Encryptor.decrypt(row[:encrypted_buildpack], row[:salt])
      self['UPDATE buildpack_lifecycle_data SET buildpack = ? WHERE id = ?', decrypted, row[:id]].update
    end

    alter_table(:buildpack_lifecycle_data) do
      drop_column :salt
      drop_column :encrypted_buildpack
    end

    alter_table(:apps) do
      add_column :buildpack
    end

    self[:apps].each do |row|
      decrypted = VCAP::CloudController::Encryptor.decrypt(row[:encrypted_buildpack], row[:buildpack_salt])
      self['UPDATE apps SET buildpack = ? WHERE id = ?', decrypted, row[:id]].update
    end

    alter_table(:apps) do
      drop_column :buildpack_salt
      drop_column :encrypted_buildpack
    end
  end
end
