Sequel.migration do
  up do
    run 'ALTER TABLE `apps` CHANGE COLUMN `encrypted_environment_json` `encrypted_environment_json` TEXT' if self.class.name.match?(/mysql/i)
  end
end
