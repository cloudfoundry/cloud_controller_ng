# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :organizations do
      add_column :billing_enabled, TrueClass, :null => false, :default => false
    end
  end
end
