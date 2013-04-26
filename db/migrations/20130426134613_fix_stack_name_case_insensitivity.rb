# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :stacks do
      set_column_type :name, String, :null => false, :case_insensitive => true
    end
  end
end
