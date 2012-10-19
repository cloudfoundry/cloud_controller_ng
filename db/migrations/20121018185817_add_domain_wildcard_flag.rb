# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :domains do
      add_column :wildcard, TrueClass, :null => false, :default => true
    end
  end
end
