Sequel.migration do
  up do
    self[:apps].filter(diego: true).each do |row|
      self[:apps].filter(id: row[:id]).update(diego: diego?(row))
    end
  end

  def diego?(row)
    decrypted = VCAP::CloudController::Encryptor.decrypt(row[:encrypted_environment_json], row[:salt])
    environment_json = JSON.parse(decrypted)
    !!(environment_json['DIEGO_RUN_BETA'] == 'true')
  end
end
