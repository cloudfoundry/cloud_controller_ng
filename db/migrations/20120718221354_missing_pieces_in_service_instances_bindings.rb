# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :service_instances do
      add_foreign_key :service_id, :services
      add_column :gateway_name, String
      add_column :gateway_data, String
      drop_column :vendor_data
    end

    alter_table :service_bindings do
      # FIXME non-null columns like this really should be squeezed into the
      # initiali schema. We need to make sure otherwise this is an empty table
      add_column :gateway_name, String, :null => false, :default => ''
      add_column :configuration, String
      add_column :gateway_data, String
      drop_column :vendor_data
    end
  end
end
