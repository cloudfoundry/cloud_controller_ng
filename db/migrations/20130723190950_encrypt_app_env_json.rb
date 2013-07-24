require File.expand_path('../../../lib/cloud_controller/encryptor', __FILE__)

Sequel.migration do
  up do
    self[:apps].each do |row|
      salt = VCAP::CloudController::Encryptor.generate_salt
      encrypted = VCAP::CloudController::Encryptor.encrypt(row[:environment_json], salt)
      self["UPDATE apps SET environment_json = ?, salt = ? WHERE id = ?", encrypted, salt, row[:id]].update
    end
  end

  down do
    self[:apps].each do |row|
      decrypted = VCAP::CloudController::Encryptor.decrypt(row[:environment_json], row[:salt])
      self["UPDATE apps SET environment_json = ?, salt = NULL WHERE id = ?", decrypted, row[:id]].update
    end
  end
end
