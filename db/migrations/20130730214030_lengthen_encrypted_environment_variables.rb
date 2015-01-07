Sequel.migration do
  up do
    if self.class.name.match /mysql/i
      run 'ALTER TABLE `apps` CHANGE COLUMN `encrypted_environment_json` `encrypted_environment_json` TEXT'
    end
  end
end
