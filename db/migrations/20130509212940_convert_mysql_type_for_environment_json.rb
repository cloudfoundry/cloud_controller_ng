Sequel.migration do
  change do
    if self.class.name.match /mysql/i
      run 'ALTER TABLE `apps` CHANGE COLUMN `environment_json` `environment_json` TEXT'
    end
  end
end
