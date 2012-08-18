# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :service_instances do
      drop_column :service_id
    end
  end
end
