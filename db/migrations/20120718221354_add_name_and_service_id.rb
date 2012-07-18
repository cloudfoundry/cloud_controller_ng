# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :service_instances do
      add_foreign_key :service_id, :services
      add_column :name_on_gateway, String
    end
  end
end
