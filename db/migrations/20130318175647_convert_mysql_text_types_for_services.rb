# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  up do
    # Sequel does not support a way to create a larger than 65k text column with mysql adapter
    if self.class.name.match /mysql/i
      run 'ALTER TABLE `services` CHANGE COLUMN `extra` `extra` MEDIUMTEXT'
      run 'ALTER TABLE `service_plans` CHANGE COLUMN `extra` `extra` MEDIUMTEXT'
    end
  end

  down do
    if self.class.name.match /mysql/i
      run 'ALTER TABLE `services` CHANGE COLUMN `extra` `extra` TEXT'
      run 'ALTER TABLE `service_plans` CHANGE COLUMN `extra` `extra` TEXT'
    end
  end
end
