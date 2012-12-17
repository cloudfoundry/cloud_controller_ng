# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :service_plans do
      add_column :free, TrueClass, :null => false, :default => true
    end
  end
end
