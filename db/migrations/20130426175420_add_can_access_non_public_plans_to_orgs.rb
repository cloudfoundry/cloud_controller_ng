# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :organizations do
      add_column :can_access_non_public_plans, TrueClass, default: false, null: false
    end
  end
end
