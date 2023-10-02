Sequel.migration do
  change do
    run 'ALTER TABLE `apps` CHANGE COLUMN `environment_json` `environment_json` TEXT' if self.class.name.match?(/mysql/i)
  end
end
